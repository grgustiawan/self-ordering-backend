 
 /*------------------------------------------------------------------------
    File        : posOrder
    Purpose     : Modul proses submit order
    Syntax      : Progress OpenEdge12
    Description : Insert data pesanan dari table cart ke table trhdr dan trdtl
    Author(s)   : Galih Raka Gustiawan
    Created     : Wed Jul 12 15:19:51 ICT 2023
    Notes       : METHOD yang di gunakan POST
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Net.URI.
USING OpenEdge.Net.HTTP.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posOrder INHERITS WebHandler: 	   
		
	/*------------------------------------------------------------------------------
            Purpose: Handler for unsupported methods. The request being serviced and
            		 an optional status code is returned. A zero or null value means 
            		 this method will deal with all errors.                                                               
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
	METHOD OVERRIDE PROTECTED INTEGER HandleNotAllowedMethod( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
	
		/* Throwing an error from this method results in a 500/Internal Server Error response. 
        The web handler will attempt to log this exception.
 	    
        See the HandleGet method's comments on choosing a value to return from this method. */
        	
		UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").
	END METHOD.


	/*------------------------------------------------------------------------------
            Purpose: Handler for unknown methods. The request being serviced and an 
                     optional status code is returned. A zero or null value means 
                     this method will deal with all errors.                                                               
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
	METHOD OVERRIDE PROTECTED INTEGER HandleNotImplemented( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
	
		/* Throwing an error from this method results in a 500/Internal Server Error response. 
        The web handler will attempt to log this exception.
 	    
        See the HandleGet method's comments on choosing a value to return from this method. */	
		UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").
   	END METHOD.
 	
	
	/*------------------------------------------------------------------------------
            Purpose: Default handler for the HTTP GET method. The request being 
                     serviced and an optional status code is returned. A zero or 
                     null value means this method will deal with all errors.                                                               
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
 	METHOD OVERRIDE PROTECTED INTEGER HandleGet( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
 	
	
		DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter  NO-UNDO.
        DEFINE VARIABLE oBody     AS OpenEdge.Core.String            NO-UNDO.
            
        ASSIGN 
            oResponse            = NEW OpenEdge.Web.WebResponse()
            oResponse:StatusCode = INTEGER(StatusCodeEnum:OK)
            .
                     
        ASSIGN 
            oBody = NEW OpenEdge.Core.String(
                             'Hello User'
                           + '~r~n':u   /*CRLF */
                           + 'This message was returned by HandleGet in posOrder.').
        
        ASSIGN 
            oResponse:Entity        = oBody
            oResponse:ContentType   = 'text/plain':u            
            oResponse:ContentLength = oBody:Size.
            
        ASSIGN 
            oWriter = NEW WebResponseWriter(oResponse).
            oWriter:Open().
            oWriter:Close().
        
        RETURN 0.
		
 	END METHOD.
 	
 	
 	/*------------------------------------------------------------------------------
            Purpose: Modul untuk proses submit order dan cetak struk pesanan ke dapur. 
                     mengembalikan data dalam bentuk Json dan status code. Return 0 
                     berarti program berjalan tanpa ada error.                                                               
            Notes :  Menggunakan paramater token untuk mengakses services ini.                                                                       
    ------------------------------------------------------------------------------*/ 
 	METHOD OVERRIDE PROTECTED INTEGER HandlePost( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
 	    
 	    /*HTTP Services*/
        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse    NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter     NO-UNDO.
        DEFINE VARIABLE oBody     AS OpenEdge.Core.String               NO-UNDO.
        DEFINE VARIABLE lcString    AS LONGCHAR                         NO-UNDO.
        
        /* Json Data */
        DEFINE VARIABLE JsonResponse AS JsonObject                      NO-UNDO.
        DEFINE VARIABLE aDtl         AS JsonArray                       NO-UNDO.
        DEFINE VARIABLE oDtl         AS JsonObject                      NO-UNDO.
        
        /* Request Body */
        DEFINE VARIABLE tokens       AS CHARACTER                       NO-UNDO.
        
        /* Operation Variables */
        DEFINE VARIABLE expTime     AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE jam         AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE menit       AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE quantity    AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE cnt-nobc    AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE cnt-notrans AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE cnt-notif   AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE btnTipe     AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE indexTipe   AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE isSubmitted AS LOGICAL      INITIAL YES         NO-UNDO.
        DEFINE VARIABLE cPrinterName AS CHARACTER                       NO-UNDO.
        
        /*Temp Table Variables*/
        DEFINE VARIABLE sid         AS INTEGER INITIAL 1                NO-UNDO.
        DEFINE VARIABLE hid         AS INTEGER INITIAL 1                NO-UNDO.
        DEFINE VARIABLE xprinter    AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE branch      AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE address     AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE meja        AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE psn         AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE mja         AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE ntrs        AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE qtycartitem AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE looptime    AS INTEGER                          NO-UNDO.
        DEFINE BUFFER bcartitem     FOR cartitem.        
        DEFINE VARIABLE WordApplication AS COM-HANDLE.
        
        /*Get token parameter*/
        tokens = poRequest:GetPathParameter("token").
        
        IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END.
        
        FIND FIRST token WHERE token.token = tokens NO-LOCK NO-ERROR.
        IF AVAIL token THEN DO:
            IF DATE(SUBSTRING(token.expdate,1,10)) < TODAY THEN DO: 
                errorValidation(401, 'Token Expired').
            END.
            IF DATE(SUBSTRING(token.expdate,1,10)) = TODAY THEN DO:
                ASSIGN
                    expTime = 0
                    jam = INT(SUBSTRING(token.expdate,12,2))
                    menit = INT(SUBSTRING(token.expdate,15,2)).
                    
                expTime = (menit * 60) + (jam * 3600).
                
                IF TIME > expTime THEN DO:
                    errorValidation(401, "Token Expired").
                END.
            END.
            
            FIND FIRST counter WHERE counter.nmcnt = 'nobc' NO-LOCK NO-ERROR.
            cnt-nobc = counter.lastno.
            FIND FIRST counter WHERE counter.nmcnt = 'notrans' NO-LOCK NO-ERROR.
            cnt-notrans = counter.lastno.
            
            FIND FIRST cart WHERE cart.token = tokens NO-ERROR.
            IF AVAIL cart THEN DO:
                
                FIND FIRST cartitem WHERE cartitem.cartid = cart.id AND
                                          cartitem.is_submitted = NO NO-LOCK NO-ERROR.
                IF AVAIL cartitem THEN DO:
                    isSubmitted = NO.
                END.
                
                FOR EACH cartitem WHERE cartitem.cartid = cart.id AND
                                            cartitem.is_submitted = NO BREAK BY cartitem.kode:
                      ASSIGN
                            quantity = quantity + cartitem.qorder.
                            

                    IF LAST-OF(cartitem.kode) THEN DO:
                        FIND FIRST limititem WHERE limititem.kode = cartitem.kode AND limititem.sdjam = '' EXCLUSIVE-LOCK NO-ERROR.
                        IF LOCKED(limititem) THEN DO:
                            looptime = TIME + 60.
                            asd:
                            REPEAT:
                                FIND FIRST limititem WHERE limititem.kode = cartitem.kode AND limititem.sdjam = '' EXCLUSIVE-LOCK NO-ERROR.
                                IF AVAIL limititem THEN DO:
                                    LEAVE asd.
                                END.
                                
                                IF TIME >= looptime THEN DO:
                                    RELEASE cart.
                                    RELEASE cartitem.
                                    RELEASE limititem.
                                    ErrorValidation(503, "Record limititem for " + cartitem.kode + " is locked").
                                END.
                            END.
                        END.
                        IF AVAIL limititem THEN DO:
                            IF limititem.qtylimit - limititem.qtyorder >= quantity THEN DO:
                                ASSIGN
                                    limititem.qtyorder = limititem.qtyorder + quantity.
                            END.
                            ELSE DO:
/*                                    ASSIGN                                                 */
/*                                        quantity = limititem.qtylimit - limititem.qtyorder */
/*                                        limititem.qtyorder = limititem.qtyorder + quantity.*/

                                RELEASE counter.
                                RELEASE cart.
                                RELEASE cartitem.
                                RELEASE limititem.
                                RELEASE notification.
                                RELEASE trhdr.
                                RELEASE trdtl.
                                RELEASE nmeja.
                                RELEASE btndtl1.
                                RELEASE tmkn.
                                RELEASE tprn.
                                RELEASE profile.
                                errorValidation(406, "Out Of Stock").
                            END.
                        END.
                        quantity = 0.
                    END.
                END.
                                
                /* INSERT TRHDR & TRDTL*/
                FIND FIRST trhdr WHERE trhdr.cartid = cart.id AND trhdr.nobill = '' 
                                 AND trhdr.meja = cart.meja NO-ERROR.
                IF AVAIL trhdr THEN DO:
                    ASSIGN
                        trhdr.tcharge = cart.tcharge
                        trhdr.tdisc   = cart.tdisc
                        trhdr.ttax    = cart.ttax
                        trhdr.total   = cart.total
                        trhdr.grand   = cart.grand
                        cnt-notrans   = trhdr.notrans.
                END.
/*                                                                                                                                                                                                  */
/*                    FOR EACH cartitem WHERE cartitem.cartid = cart.id AND                                                                                                                         */
/*                                            cartitem.is_submitted = NO BREAK BY cartitem.kode:                                                                                                    */
/*                                                                                                                                                                                                  */
/*                        ASSIGN                                                                                                                                                                    */
/*                            quantity = quantity + cartitem.qorder                                                                                                                                 */
/*                                                                                                                                                                                                  */
/*                                                                                                                                                                                                  */
/*                            qtycartitem = 0.                                                                                                                                                      */
/*                                                                                                                                                                                                  */
/*                        IF cartitem.is_submitted = NO THEN qtycartitem = cartitem.qorder.                                                                                                         */
/*                                                                                                                                                                                                  */
/*                        IF LAST-OF(cartitem.kode) THEN DO:                                                                                                                                        */
/*                            FIND FIRST trdtl WHERE trdtl.notrans = trhdr.notrans AND                                                                                                              */
/*                                                   trdtl.cartid = cartitem.cartid AND                                                                                                             */
/*                                                   trdtl.kode   = cartitem.kode NO-ERROR.                                                                                                         */
/*                            IF AVAIL trdtl THEN DO:                                                                                                                                               */
/*                                FIND FIRST limititem WHERE limititem.kode = trdtl.kode AND limititem.sdjam = '' NO-ERROR.                                                                         */
/*                                IF AVAIL limititem THEN DO:                                                                                                                                       */
/*                                    IF limititem.qtylimit - limititem.qtyorder < qtycartitem THEN DO:                                                                                             */
/*                                        qtycartitem = limititem.qtylimit - limititem.qtyorder.                                                                                                    */
/*                                    END.                                                                                                                                                          */
/*                                    IF limititem.qtylimit - limititem.qtyorder >= quantity THEN DO:                                                                                               */
/*                                        ASSIGN                                                                                                                                                    */
/*                                            limititem.qtyorder = limititem.qtyorder + quantity.                                                                                                   */
/*                                    END.                                                                                                                                                          */
/*                                    ELSE DO:                                                                                                                                                      */
/*                                        ASSIGN                                                                                                                                                    */
/*                                            quantity = limititem.qtylimit - limititem.qtyorder                                                                                                    */
/*                                            limititem.qtyorder = limititem.qtyorder + quantity.                                                                                                   */
/*                                    END.                                                                                                                                                          */
/*                                END. /* end dari limit item */                                                                                                                                    */
/*                                IF qtycartitem = 0 THEN DO:                                                                                                                                       */
/*                                    RELEASE counter.                                                                                                                                              */
/*                                    RELEASE cart.                                                                                                                                                 */
/*                                    RELEASE cartitem.                                                                                                                                             */
/*                                    RELEASE limititem.                                                                                                                                            */
/*                                    RELEASE notification.                                                                                                                                         */
/*                                    RELEASE trhdr.                                                                                                                                                */
/*                                    RELEASE trdtl.                                                                                                                                                */
/*                                    RELEASE nmeja.                                                                                                                                                */
/*                                    RELEASE btndtl1.                                                                                                                                              */
/*                                    RELEASE tmkn.                                                                                                                                                 */
/*                                    RELEASE tprn.                                                                                                                                                 */
/*                                    RELEASE profile.                                                                                                                                              */
/*                                    errorValidation(406, "Out Of Stock").                                                                                                                         */
/*                                END.                                                                                                                                                              */
/*                                IF token.is_reserv = YES THEN DO:                                                                                                                                 */
/*                                    FIND FIRST rsvdtl WHERE rsvdtl.noreserv = token.noreserv AND rsvdtl.kode = trdtl.kode NO-ERROR.                                                               */
/*                                    IF AVAIL rsvdtl THEN DO:                                                                                                                                      */
/*                                       ASSIGN                                                                                                                                                     */
/*                                            rsvdtl.qtyout = rsvdtl.qtyout + quantity.                                                                                                             */
/*                                    END.                                                                                                                                                          */
/*                                END.                                                                                                                                                              */
/*                                                                                                                                                                                                  */
/*                                ASSIGN                                                                                                                                                            */
/*                                    trdtl.qorder  = trdtl.qorder + quantity                                                                                                                       */
/*                                    trdtl.harga   = cartitem.shrg                                                                                                                                 */
/*                                    trdtl.ncharge = cartitem.ncharge                                                                                                                              */
/*                                    trdtl.tcharge = cartitem.tcharge                                                                                                                              */
/*                                    trdtl.ndisc   = cartitem.ndisc                                                                                                                                */
/*                                    trdtl.tdisc   = cartitem.tdisc                                                                                                                                */
/*                                    trdtl.ntax    = cartitem.ntax                                                                                                                                 */
/*                                    trdtl.ttax    = cartitem.ttax                                                                                                                                 */
/*                                    quantity = 0.                                                                                                                                                 */
/*                                RELEASE trdtl.                                                                                                                                                    */
/*                                                                                                                                                                                                  */
/*                                FIND FIRST bcartitem WHERE bcartitem.cartid = cartitem.cartid AND                                                                                                 */
/*                                                           bcartitem.kode = cartitem.kode AND                                                                                                     */
/*                                                           bcartitem.is_submitted = NO NO-ERROR.                                                                                                  */
/*                               IF AVAIL bcartitem THEN bcartitem.qorder = qtycartitem.                                                                                                            */
/*                                                                                                                                                                                                  */
/*                            END. /* End dari if avail trdtl */                                                                                                                                    */
/*                            ELSE DO:                                                                                                                                                              */
/*                                FIND FIRST limititem WHERE limititem.kode = trdtl.kode AND limititem.sdjam = '' NO-ERROR.                                                                         */
/*                                IF AVAIL limititem THEN DO:                                                                                                                                       */
/*                                    IF limititem.qtylimit - limititem.qtyorder >= quantity THEN DO:                                                                                               */
/*                                        ASSIGN                                                                                                                                                    */
/*/*                                            limititem.qtyorder = limititem.qtyorder - trdtl.qorder*/                                                                                            */
/*                                            limititem.qtyorder = limititem.qtyorder + quantity.                                                                                                   */
/*                                    END.                                                                                                                                                          */
/*                                    ELSE DO:                                                                                                                                                      */
/*                                                                                                                                                                                                  */
/*                                        ASSIGN                                                                                                                                                    */
/*                                            quantity = limititem.qtylimit - limititem.qtyorder                                                                                                    */
/*/*                                            limititem.qtyorder = limititem.qtyorder - trdtl.qorder*/                                                                                            */
/*                                            limititem.qtyorder = limititem.qtyorder + quantity.                                                                                                   */
/*                                    END.                                                                                                                                                          */
/*                                END.                                                                                                                                                              */
/*                                IF quantity = 0 THEN DO:                                                                                                                                          */
/*                                    RELEASE counter.                                                                                                                                              */
/*                                    RELEASE cart.                                                                                                                                                 */
/*                                    RELEASE cartitem.                                                                                                                                             */
/*                                    RELEASE limititem.                                                                                                                                            */
/*                                    RELEASE notification.                                                                                                                                         */
/*                                    RELEASE trhdr.                                                                                                                                                */
/*                                    RELEASE trdtl.                                                                                                                                                */
/*                                    RELEASE nmeja.                                                                                                                                                */
/*                                    RELEASE btndtl1.                                                                                                                                              */
/*                                    RELEASE tmkn.                                                                                                                                                 */
/*                                    RELEASE tprn.                                                                                                                                                 */
/*                                    RELEASE profile.                                                                                                                                              */
/*                                    errorValidation(406, "Out Of Stock").                                                                                                                         */
/*                                END.                                                                                                                                                              */
/*                                                                                                                                                                                                  */
/*                                IF token.is_reserv = YES THEN DO:                                                                                                                                 */
/*                                    FIND FIRST rsvdtl WHERE rsvdtl.noreserv = token.noreserv AND rsvdtl.kode = cartitem.kode NO-ERROR.                                                            */
/*                                    IF AVAIL rsvdtl THEN DO:                                                                                                                                      */
/*                                       ASSIGN                                                                                                                                                     */
/*                                            rsvdtl.qtyout = rsvdtl.qtyout + quantity.                                                                                                             */
/*                                    END.                                                                                                                                                          */
/*                                END.                                                                                                                                                              */
/*                                                                                                                                                                                                  */
/*                                ASSIGN                                                                                                                                                            */
/*                                    btnTipe = ''                                                                                                                                                  */
/*                                    indexTipe = ''.                                                                                                                                               */
/*                                IF cartitem.main_food = '' THEN DO:                                                                                                                               */
/*                                    FIND FIRST btndtl1 WHERE btndtl1.kode = cartitem.kode NO-LOCK NO-ERROR.                                                                                       */
/*                                    IF AVAIL btndtl1 THEN ASSIGN btnTipe = btndtl1.tipe                                                                                                           */
/*                                                                 indexTipe = '00'.                                                                                                                */
/*                                END.                                                                                                                                                              */
/*                                ELSE DO:                                                                                                                                                          */
/*                                    FIND FIRST btndtl2 WHERE btndtl2.kodedtl = cartitem.kode NO-LOCK NO-ERROR.                                                                                    */
/*                                    IF AVAIL btndtl2 THEN ASSIGN btnTipe = btndtl2.tipe                                                                                                           */
/*                                                                 indexTipe = '01'.                                                                                                                */
/*                                END.                                                                                                                                                              */
/*                                                                                                                                                                                                  */
/*                                CREATE trdtl.                                                                                                                                                     */
/*                                ASSIGN                                                                                                                                                            */
/*                                    trdtl.cartid = cart.id                                                                                                                                        */
/*                                    trdtl.pesanan = trhdr.pesanan                                                                                                                                 */
/*                                    trdtl.meja = trhdr.meja                                                                                                                                       */
/*                                    trdtl.notrans = trhdr.notrans                                                                                                                                 */
/*                                    trdtl.tgl = STRING(TODAY, "99/99/9999")                                                                                                                       */
/*                                    trdtl.urut = cartitem.urut                                                                                                                                    */
/*                                    trdtl.kode = cartitem.kode                                                                                                                                    */
/*                                    trdtl.qorder = quantity                                                                                                                                       */
/*                                    trdtl.harga = cartitem.shrg                                                                                                                                   */
/*                                    trdtl.ncharge = cartitem.ncharge                                                                                                                              */
/*                                    trdtl.tcharge = cartitem.tcharge                                                                                                                              */
/*                                    trdtl.ndisc = cartitem.ndisc                                                                                                                                  */
/*                                    trdtl.tdisc = cartitem.tdisc                                                                                                                                  */
/*                                    trdtl.ntax = cartitem.ntax                                                                                                                                    */
/*                                    trdtl.ttax = cartitem.ttax                                                                                                                                    */
/*                                    cnt-nobc = cnt-nobc + 1                                                                                                                                       */
/*                                    trdtl.nobc = STRING(cnt-nobc, '99999999')                                                                                                                     */
/*                                    trdtl.starttime = STRING(TIME, "HH:MM")                                                                                                                       */
/*                                    trdtl.endtime = STRING(TIME, "HH:MM")                                                                                                                         */
/*                                    trdtl.frelease = 0                                                                                                                                            */
/*                                    trdtl.cetak = ''                                                                                                                                              */
/*                                    trdtl.fprint = 0                                                                                                                                              */
/*                                    trdtl.prnprice = 0                                                                                                                                            */
/*                                    trdtl.tipe = btnTipe                                                                                                                                          */
/*                                    trdtl.catat = cartitem.catat                                                                                                                                  */
/*                                    trdtl.indexkey = '1' + trdtl.pesanan + trdtl.meja + SUBSTRING(trdtl.starttime, 1 ,2) + SUBSTRING(trdtl.starttime, 4,2) + indexTipe + STRING(trdtl.urut, '999')*/
/*                                    cartitem.qorder = quantity.                                                                                                                                   */
/*                                RELEASE trdtl.                                                                                                                                                    */
/*                            END.                                                                                                                                                                  */
/*                                                                                                                                                                                                  */
/*                            quantity = 0.                                                                                                                                                         */
/*                        END.                                                                                                                                                                      */
/*                    END. /* End dari for each cartitem */                                                                                                                                         */
/*                                                                                                                                                                                                  */
/*                    FOR EACH cartitem WHERE cartitem.cartid = cart.id:                                                                                                                            */
/*                        cartitem.is_submitted = YES.                                                                                                                                              */
/*                    END.                                                                                                                                                                          */
/*                END. /* End dari avail trhdr */                                                                                                                                                   */
                ELSE DO:
                    CREATE trhdr.
                    ASSIGN
                        trhdr.cartid = cart.id
                        trhdr.pesanan = SUBSTRING(STRING(TIME, "HH:MM"), 1,2) + SUBSTRING(STRING(TIME, "HH:MM"),4,2)
                        trhdr.meja = token.meja
                        cnt-notrans = cnt-notrans + 1
                        trhdr.notrans = cnt-notrans
                        trhdr.tgl = STRING(TODAY, '99/99/9999')
                        trhdr.tcharge = cart.tcharge
                        trhdr.tdisc = cart.tdisc
                        trhdr.ttax = cart.ttax
                        trhdr.total = cart.total
                        trhdr.grand = cart.grand
                        trhdr.nobill = ""
                        trhdr.ftakeaway = 0
                        trhdr.kharga = '1'
                        trhdr.jumorang = 1
                        trhdr.cookstarttime = STRING(TIME, "HH:MM:SS").
                    END.                    
                    
                    DO TRANSACTION:
                        FIND FIRST nmeja WHERE nmeja.kdmeja = token.meja NO-ERROR.
                        IF AVAIL nmeja THEN DO:
                            ASSIGN
                                nmeja.kondisi = 'I'.
                        END.
                    END.
                    
                    FOR EACH cartitem WHERE cartitem.cartid = cart.id AND 
                                            cartitem.is_submitted = NO BREAK BY cartitem.kode:
                        
                        ASSIGN                        
                            quantity = quantity + cartitem.qorder
                            cartitem.is_submitted = YES.
                        
                        IF LAST-OF(cartitem.kode) THEN DO:                         
/*                            FIND FIRST limititem WHERE limititem.kode = cartitem.kode AND limititem.sdjam = '' EXCLUSIVE-LOCK NO-ERROR.        */
/*                            IF LOCKED(limititem) THEN DO:                                                                                      */
/*                                asd:                                                                                                           */
/*                                REPEAT:                                                                                                        */
/*                                    FIND FIRST limititem WHERE limititem.kode = cartitem.kode AND limititem.sdjam = '' EXCLUSIVE-LOCK NO-ERROR.*/
/*                                    IF AVAIL limititem THEN DO:                                                                                */
/*                                        LEAVE asd.                                                                                             */
/*                                    END.                                                                                                       */
/*                                END.                                                                                                           */
/*                            END.                                                                                                               */
/*                            IF AVAIL limititem THEN DO:                                                                                        */
/*                                IF limititem.qtylimit - limititem.qtyorder >= quantity THEN DO:                                                */
/*                                    ASSIGN                                                                                                     */
/*                                        limititem.qtyorder = limititem.qtyorder + quantity.                                                    */
/*                                END.                                                                                                           */
/*                                ELSE DO:                                                                                                       */
/*/*                                    ASSIGN                                                 */                                                */
/*/*                                        quantity = limititem.qtylimit - limititem.qtyorder */                                                */
/*/*                                        limititem.qtyorder = limititem.qtyorder + quantity.*/                                                */
/*                                                                                                                                               */
/*                                    RELEASE counter.                                                                                           */
/*                                    RELEASE cart.                                                                                              */
/*                                    RELEASE cartitem.                                                                                          */
/*                                    RELEASE limititem.                                                                                         */
/*                                    RELEASE notification.                                                                                      */
/*                                    RELEASE trhdr.                                                                                             */
/*                                    RELEASE trdtl.                                                                                             */
/*                                    RELEASE nmeja.                                                                                             */
/*                                    RELEASE btndtl1.                                                                                           */
/*                                    RELEASE tmkn.                                                                                              */
/*                                    RELEASE tprn.                                                                                              */
/*                                    RELEASE profile.                                                                                           */
/*                                    errorValidation(406, "Out Of Stock").                                                                      */
/*                                END.                                                                                                           */
/*                            END.                                                                                                               */
/*                            IF quantity = 0 THEN DO:                                                                                           */
/*                                    RELEASE counter.                                                                                           */
/*                                    RELEASE cart.                                                                                              */
/*                                    RELEASE cartitem.                                                                                          */
/*                                    RELEASE limititem.                                                                                         */
/*                                    RELEASE notification.                                                                                      */
/*                                    RELEASE trhdr.                                                                                             */
/*                                    RELEASE trdtl.                                                                                             */
/*                                    RELEASE nmeja.                                                                                             */
/*                                    RELEASE btndtl1.                                                                                           */
/*                                    RELEASE tmkn.                                                                                              */
/*                                    RELEASE tprn.                                                                                              */
/*                                    RELEASE profile.                                                                                           */
/*                                    errorValidation(406, "Out Of Stock").                                                                      */
/*                            END.                                                                                                               */
                            
                            IF token.is_reserv = YES THEN DO:
                                FIND FIRST rsvdtl WHERE rsvdtl.noreserv = token.noreserv AND rsvdtl.kode = cartitem.kode NO-ERROR.
                                IF AVAIL rsvdtl THEN DO:
                                   ASSIGN
                                        rsvdtl.qtyout = rsvdtl.qtyout + quantity. 
                                END.
                            END.                         
                            
                            ASSIGN
                                btnTipe = ''
                                indexTipe = ''.
                            IF cartitem.main_food = '' THEN DO:
                                FIND FIRST btndtl1 WHERE btndtl1.kode = cartitem.kode NO-LOCK NO-ERROR.
                                IF AVAIL btndtl1 THEN ASSIGN btnTipe = btndtl1.tipe
                                                             indexTipe = '00'.
                            END.
                            ELSE DO:
                                FIND FIRST btndtl2 WHERE btndtl2.kodedtl = cartitem.kode NO-LOCK NO-ERROR.
                                IF AVAIL btndtl2 THEN ASSIGN btnTipe = btndtl2.tipe
                                                             indexTipe = '01'.
                            END.
                            
                            CREATE trdtl.
                            ASSIGN
                                trdtl.cartid = cart.id
                                trdtl.pesanan = trhdr.pesanan
                                trdtl.meja = trhdr.meja
                                trdtl.notrans = trhdr.notrans
                                trdtl.tgl   = STRING(TODAY, "99/99/9999")
                                trdtl.urut  = cartitem.urut
                                trdtl.kode = cartitem.kode
                                trdtl.qorder = quantity                                
                                trdtl.harga = cartitem.shrg
                                trdtl.ncharge = cartitem.ncharge
                                trdtl.tcharge = cartitem.tcharge
                                trdtl.ndisc = cartitem.ndisc
                                trdtl.tdisc = cartitem.tdisc
                                trdtl.ntax = cartitem.ntax
                                trdtl.ttax = cartitem.ttax                                
                                trdtl.starttime = STRING(TIME, "HH:MM")
                                trdtl.frelease = 0
                                trdtl.cetak = ''
                                trdtl.fprint = 0
                                trdtl.prnprice = 0
                                trdtl.tipe = btnTipe
                                trdtl.sdhstruk = 0
                                trdtl.catat = cartitem.catat
                                trdtl.qcheck = 0                                
                                trdtl.indexkey = '1' + trdtl.pesanan + trhdr.meja + SUBSTRING(trdtl.starttime,1, 2) + SUBSTRING(trdtl.starttime, 4,2) + indexTipe + STRING(trdtl.urut, '999')
/*                                cartitem.qorder = quantity*/
                                quantity = 0.
                                IF cartitem.main_food = "" THEN DO:
                                    ASSIGN
                                        cnt-nobc = cnt-nobc + 1
                                        trdtl.nobc = STRING(cnt-nobc, '99999999').
                                END.
                                ELSE trdtl.endtime = STRING(TIME, "HH:MM").
                                RELEASE trdtl.                                                        
                        END.
                    END.
/*                END.*/
                jsonResponse = NEW JsonObject().
                IF isSubmitted = NO THEN DO:
                    FIND LAST notification NO-LOCK NO-ERROR.
                    IF AVAIL notification THEN cnt-notif = notification.id + 1.
                    ELSE cnt-notif = 1.
                    
                    CREATE notification.
                    ASSIGN
                        notification.id = cnt-notif
                        notification.cartid = cart.id
                        notification.titles = 'Order Submitted'
                        notification.msg = 'Your order is submitted to kitchen. Please wait, your food will be served immediately.'                   
                        notification.priority = 'low'
                        notification.is_open = NO
                        notification.crdate = STRING(TODAY, "99/99/9999") + ';' + STRING(TIME, "HH:MM").
                        jsonResponse:Add('message', 'Cart Submitted').
                    RELEASE notification.                    
                END.
                ELSE DO:                    
                    jsonResponse:Add('message', "There's no items added").
                END.
                
                cart.is_submitted = YES.                                
                                                
                jsonResponse:Add('id', cart.id).
                jsonResponse:Add('meja', cart.meja).
                jsonResponse:Add('member-id', cart.member-id).
                jsonResponse:Add('is_submitted', cart.is_submitted).
                jsonResponse:Add('tcharge', cart.tcharge).
                jsonResponse:Add('tdisc', cart.tdisc).
                jsonResponse:Add('ttax', cart.ttax).
                jsonResponse:Add('total', cart.total).
                jsonResponse:Add('tqty', cart.tqty).
                jsonResponse:Add('grand', cart.grand).
                
                FIND FIRST profile NO-LOCK NO-ERROR.                                                 
                    
/*                RUN D:\Tamani\Workspace3\api\PrintStrukDapurAPI.p (INPUT token.token).*/
                                               
                FIND FIRST counter WHERE counter.nmcnt = 'nobc' NO-ERROR. 
                counter.lastno = cnt-nobc.
                FIND FIRST counter WHERE counter.nmcnt = 'notrans' NO-ERROR.
                counter.lastno = cnt-notrans.                
                
                RELEASE counter.
                RELEASE cart.
                RELEASE cartitem.
                RELEASE limititem.
                RELEASE notification.
                RELEASE trhdr.
                RELEASE trdtl.
                RELEASE nmeja.
                RELEASE btndtl1.
                RELEASE tmkn.
                RELEASE tprn.
                RELEASE profile.                               
            
                ASSIGN
                    oResponse            = NEW OpenEdge.Web.WebResponse().
                  
                ASSIGN 
                    lcString = jsonResponse:GetJsonText().
                    oBody = NEW OpenEdge.Core.String(lcString).
                
                ASSIGN 
                    oResponse:Entity        = jsonResponse
                    oResponse:ContentType   = 'application/json':u
                    oResponse:ContentLength = oBody:Size
                    oResponse:StatusCode    = INTEGER(201).
                
                ASSIGN 
                    oWriter = NEW WebResponseWriter(oResponse).
                    oWriter:Open().
                    oWriter:Close().                                                   
                                    
            END.            
        END.
        ELSE DO:
            errorValidation(401, "Unauthorized").
        END.
        
 	  RETURN 0.    
    END METHOD.
    

    /*------------------------------------------------------------------------------
            Purpose: Modul untuk membuat pesan error dalam bentuk data json.                                                                 
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
    METHOD PUBLIC CHARACTER errorValidation(INPUT errorCode AS INTEGER, INPUT errorMessage AS CHARACTER) :
            DEFINE VARIABLE oResponse       AS OpenEdge.Net.HTTP.IHttpResponse      NO-UNDO.
            DEFINE VARIABLE oRequest        AS OpenEdge.Net.HTTP.IHttpRequest       NO-UNDO.
            DEFINE VARIABLE oWriter         AS OpenEdge.Web.WebResponseWriter       NO-UNDO.
            DEFINE VARIABLE oBody           AS OpenEdge.Core.String                 NO-UNDO.
            DEFINE VARIABLE oJsonObject     AS JsonObject                           NO-UNDO.
            DEFINE VARIABLE lcJsonObject    AS LONGCHAR                             NO-UNDO.      
            
            ASSIGN
                oResponse   = NEW OpenEdge.Web.WebResponse().
                
                oJsonObject = NEW JsonObject().
                oJsonObject:Add('success', FALSE).
                oJsonObject:Add('errorMessage', errorMessage).
                
            ASSIGN
                lcJsonObject    = oJsonObject:GetJsonText().
                oBody           = NEW OpenEdge.Core.String(lcJsonObject).
            
            ASSIGN 
                oResponse:Entity        = oJsonObject
                oResponse:ContentType   = 'application/json':u
                oResponse:ContentLength = oBody:Size
                oResponse:StatusCode    = errorCode.
                
            ASSIGN
                oWriter = NEW WebResponseWriter(oResponse).
                oWriter:Open().
                oWriter:Close().
            
            STOP.
      END METHOD.
 	
END CLASS.