 
 /*------------------------------------------------------------------------
    File        : posUpdateCart
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : User
    Created     : Thu Jul 13 18:19:28 ICT 2023
    Notes       : 
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.WebResponseWriter.
USING OpenEdge.Net.HTTP.StatusCodeEnum.
USING OpenEdge.Web.WebHandler.
USING Progress.Json.ObjectModel.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posUpdateCart INHERITS WebHandler: 

    METHOD OVERRIDE PROTECTED INTEGER HandleNotAllowedMethod( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").

    END METHOD.

    METHOD OVERRIDE PROTECTED INTEGER HandleNotImplemented( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").

    END METHOD.

    
    
     
       
     /*------------------------------------------------------------------------------
            Purpose:                                                                
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
     METHOD OVERRIDE PROTECTED INTEGER HandlePost( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        /* HTTP Services */
        DEFINE VARIABLE oResponse       AS OpenEdge.Net.HTTP.IHttpResponse      NO-UNDO.
        DEFINE VARIABLE oWriter         AS OpenEdge.Web.WebResponseWriter       NO-UNDO.
        DEFINE VARIABLE oBody           AS OpenEdge.Core.String                 NO-UNDO.
        DEFINE VARIABLE lcString        AS LONGCHAR                             NO-UNDO.

        /* Json Data*/
        DEFINE VARIABLE jsonRequest     AS JsonObject                           NO-UNDO.
        DEFINE VARIABLE jsonResponse    AS JsonObject                           NO-UNDO.
        DEFINE VARIABLE aCartItem       AS JsonArray                            NO-UNDO.
        DEFINE VARIABLE oCartItem       AS JsonObject                           NO-UNDO.
        DEFINE VARIABLE oCart           AS JsonObject                           NO-UNDO.
        DEFINE VARIABLE aOptions        AS JsonArray                            NO-UNDO.
        DEFINE VARIABLE oOptions        AS JsonObject                           NO-UNDO.

        /* Request Body */
        DEFINE VARIABLE tokens          AS CHARACTER                            NO-UNDO.
        DEFINE VARIABLE kodex           AS CHARACTER                            NO-UNDO.
        DEFINE VARIABLE quantity        AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE hargaJual       AS DECIMAL                              NO-UNDO.
        DEFINE VARIABLE serviceCharge   AS DECIMAL                              NO-UNDO.
        DEFINE VARIABLE discounts       AS DECIMAL                              NO-UNDO.
        DEFINE VARIABLE tax             AS DECIMAL                              NO-UNDO.
        DEFINE VARIABLE option1         AS CHARACTER                            NO-UNDO.
        DEFINE VARIABLE option2         AS CHARACTER                            NO-UNDO.

        /* Validation Variable*/
        DEFINE VARIABLE errorMessage    AS CHARACTER                            NO-UNDO.
        DEFINE VARIABLE errorJson       AS JsonObject                           NO-UNDO.
        DEFINE VARIABLE lcErrJs         AS LONGCHAR                             NO-UNDO.
        DEFINE VARIABLE counterErr      AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE l               AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE lqty            AS INTEGER                              NO-UNDO.

        /* Operation Variable */
        DEFINE VARIABLE jam             AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE menit           AS INTEGER                              NO-UNDO.        
        DEFINE VARIABLE expTime         AS INTEGER                              NO-UNDO.
        
        DEFINE VARIABLE arrayIndex      AS INTEGER      INITIAL 0               NO-UNDO.
        DEFINE VARIABLE total_charge    AS DECIMAL      INITIAL 0               NO-UNDO.
        DEFINE VARIABLE total_discount  AS DECIMAL      INITIAL 0               NO-UNDO.
        DEFINE VARIABLE total_tax       AS DECIMAL      INITIAL 0               NO-UNDO.
        DEFINE VARIABLE total_harga     AS DECIMAL      INITIAL 0               NO-UNDO.
        DEFINE VARIABLE grand_total     AS DECIMAL      INITIAL 0               NO-UNDO.
        DEFINE VARIABLE idx             AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE qty_stock       AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE set_active      AS INTEGER      INITIAL 1               NO-UNDO.
        DEFINE VARIABLE nou             AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE total_qty       AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE main_id         AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE id-increment    AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE cartitem-id     AS INTEGER                              NO-UNDO.
        DEFINE VARIABLE qty_main        AS INTEGER                              NO-UNDO.      
        DEFINE VARIABLE optloop         AS INTEGER                              NO-UNDO.
        
        /* Buffer Table */
        DEFINE BUFFER bcartitem FOR cartitem.
        DEFINE BUFFER blimititem FOR limititem. 
        
        IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END. 
        
        tokens  = poRequest:GetPathParameter("token").
        
        FIND FIRST token WHERE token.token = tokens NO-LOCK NO-ERROR.
        IF AVAIL token THEN DO:
            IF DATE(SUBSTRING(token.expdate,1,10)) < TODAY THEN DO:
                errorvalidation(401, "Token Expired").
            END.
            IF DATE(SUBSTRING(token.expdate,1,10)) = TODAY THEN DO:
                ASSIGN
                    expTime = 0
                    jam = INT(SUBSTRING(token.expdate, 12,2))
                    menit = INT(SUBSTRING(token.expdate,15,2)).

                expTime = (menit * 60) + (jam * 3600).

                IF TIME > expTime THEN DO:
                    errorvalidation(401, "Token Expired").
                END.
            END.

            IF TYPE-OF(poRequest:Entity, JsonObject) THEN DO :
                jsonRequest = CAST(poRequest:Entity, JsonObject).
            END.
            ELSE DO :
                errorValidation(400, "Bad Request").
            END.
            
            validateRequest('foods', 'ARRAY', TRUE, jsonRequest, errorMessage).
            IF errorMessage <> "" THEN DO:
                errorValidation(400, "Bad Request").
            END.            
            
            aCartItem = jsonRequest:GetJsonArray("foods").
            
            errorJson = NEW JsonObject().
            jsonResponse = NEW JsonObject().
                                              
            DO arrayIndex = 1 TO aCartItem:Length:
                
                oCartItem = NEW JsonObject().
                oCartItem = aCartItem:GetJsonObject(arrayIndex).
                
                                                
/*                validateRequest('kode', 'STRING', TRUE, oCartItem, errorMessage).*/
/*                IF errorMessage <> "" THEN DO :                                  */
/*                    l = l + 1.                                                   */
/*                    errorJson:Add('errorMessage ' + STRING(l), errorMessage).    */
/*                END.                                                             */
                
/*                validateRequest('qty', 'NUMBER', TRUE, oCartItem, errorMessage).*/
/*                IF errorMessage <> "" THEN DO :                                 */
/*                    l = l + 1.                                                  */
/*                    errorJson:Add('errorMessage ' + STRING(l), errorMessage).   */
/*                END.                                                            */
                                
/*                validateRequest('harga', 'NUMBER', TRUE, oCartItem, errorMessage).*/
/*                IF errorMessage <> "" THEN DO :                                   */
/*                    l = l + 1.                                                    */
/*                    errorJson:Add('errorMessage ' + STRING(l), errorMessage).     */
/*                END.                                                              */
    
/*                validateRequest('service_charge', 'NUMBER', TRUE, oCartItem, errorMessage).*/
/*                IF errorMessage <> "" THEN DO :                                            */
/*                    l = l + 1.                                                             */
/*                    errorJson:Add('errorMessage ' + STRING(l), errorMessage).              */
/*                END.                                                                       */
    
/*                validateRequest('tax', 'NUMBER', TRUE, oCartItem, errorMessage).*/
/*                IF errorMessage <> "" THEN DO :                                 */
/*                    l = l + 1.                                                  */
/*                    errorJson:Add('errorMessage ' + STRING(l), errorMessage).   */
/*                END.                                                            */
    
/*                validateRequest('discount', 'NUMBER', TRUE, oCartItem, errorMessage).*/
/*                IF errorMessage <> "" THEN DO :                                      */
/*                    l = l + 1.                                                       */
/*                    errorJson:Add('errorMessage ' + STRING(l), errorMessage).        */
/*                END.                                                                 */
    
                lcErrJs     = errorJson:GetJsonText().
                counterErr  = LENGTH(lcErrJs, "CHARACTER").
                IF counterErr > 17 THEN DO :
                    terminateService(errorJson).
                END.
                                
                kodex           = oCartItem:GetCharacter("kode").
                hargaJual       = oCartItem:GetDecimal("harga").
                quantity        = oCartItem:GetInteger("qty").
                serviceCharge   = oCartItem:GetDecimal("service_charge").
                discounts       = oCartItem:GetDecimal("discount").
                tax             = oCartItem:GetDecimal("tax").
                option1         = oCartItem:GetCharacter("opt1").
                option2         = oCartItem:GetCharacter("opt2").    
                
                IF quantity <= 0  OR hargaJual < 0 OR serviceCharge < 0 OR discounts < 0 OR tax < 0 THEN DO:
                    errorValidation(400, "Invalid request").
                END.            
                                                
                FIND FIRST cart WHERE cart.token = tokens NO-ERROR.
                IF AVAIL cart THEN DO :
                    
                    IF cart.is_submitted = YES THEN DO:
                        errorValidation(406, "Cart Already Submitted").
                    END.                                       
                    
                    IF arrayIndex = 1 THEN DO:
                        FIND FIRST cartitem WHERE cartitem.cartid    = cart.id AND 
                                                  cartitem.kode      = kodex AND                                               
                                                  cartitem.opt1      = option1 AND
                                                  cartitem.opt2      = option2  
                                                  NO-ERROR.
                    END.
                    ELSE DO:    
                    FIND FIRST cartitem WHERE cartitem.cartid    = cart.id AND 
                                              cartitem.kode      = kodex AND
                                              cartitem.main_food = string(main_id) AND 
                                              cartitem.opt1      = option1 AND
                                              cartitem.opt2      = option2 
                                              NO-ERROR.
                    END.
                    IF AVAIL cartitem THEN DO:
                        IF cartitem.is_submitted = YES THEN DO:
                            errorValidation(400, "Item already submitted").
                        END.
                        IF arrayIndex = 1 THEN DO:
                             main_id = cartitem.id.
                             cartitem-id = cartitem.id.
                         END.
                        
                        IF token.is_reserv = YES THEN DO:
                            FIND FIRST rsvdtl WHERE rsvdtl.noreserv = token.noreserv AND rsvdtl.kode = kodex NO-ERROR.
                            IF AVAIL rsvdtl THEN DO:
                                qty_stock = rsvdtl.qorder - rsvdtl.qtyout.
                                IF qty_stock > 0 AND qty_stock < quantity THEN DO:
                                    quantity = qty_stock.
                                    set_active = 1.
                                    lqty = lqty + 1.
                                    jsonResponse:Add('qty' + STRING(lqty), kodex + ' limititem < qtyorder').
                                END.
                                ELSE IF qty_stock <= 0 THEN DO:
                                    quantity = 0.
                                    set_active = 0.
                                    lqty = lqty + 1.
                                    jsonResponse:Add('qty' + STRING(lqty), kodex + ' limititem < qtyorder').
                                END.
                                ELSE set_active = 1.     
                            END.
                        END.
                        ELSE DO:
                            FIND FIRST limititem WHERE limititem.kode = kodex AND limititem.sdjam = "" NO-LOCK NO-ERROR.
                            IF AVAIL limititem THEN DO :
                                qty_stock = limititem.qtylimit - limititem.qtyorder.
                                IF qty_stock > 0 AND qty_stock < quantity THEN DO :
                                    ASSIGN
                                        quantity = qty_stock
                                        set_active = 1
                                        lqty = lqty + 1.
                                    jsonResponse:Add('qty' + STRING(lqty), kodex + ' limititem < qtyorder').
                                END.
                                ELSE IF qty_stock = 0 THEN DO:
                                    ASSIGN
                                        quantity = qty_stock
                                        set_active = 0
                                        lqty = lqty + 1.
                                    jsonResponse:Add('qty' + STRING(lqty), kodex + ' = 0').
                                END.
                                ELSE set_active = 1.
                            END.
                            ELSE set_active = 1.
                        END.                                              
                    
                        ASSIGN
                            cartitem.qorder    = quantity
                            cartitem.harga     = hargaJual * quantity
                            cartitem.tcharge   = serviceCharge * quantity
                            cartitem.ttax      = ((hargaJual * tax) / 100 ) * quantity
                            cartitem.tdisc     = ((hargaJual * discounts) / 100) * quantity
                            cartitem.grand     = cartitem.harga + cartitem.tcharge + cartitem.ttax - cartitem.tdisc
                            cartitem.is-active = set_active.                                              
                                                                                                
                    END.
                END.
            END.
            
            
            FOR EACH cartitem WHERE cartitem.cartid = cart.id NO-LOCK:
               ASSIGN
                   total_charge    = total_charge + cartitem.tcharge
                   total_discount  = total_discount + cartitem.tdisc
                   total_tax       = total_tax + cartitem.ttax
                   total_harga     = total_harga + cartitem.harga.
               IF cartitem.main_food = '' THEN total_qty = total_qty + cartitem.qorder.
                   
            END.                                       
            grand_total     = total_harga + total_charge + total_tax - total_discount.
            
            ASSIGN
                cart.tcharge    = total_charge
                cart.tdisc      = total_discount
                cart.ttax       = total_tax
                cart.total      = total_harga
                cart.grand      = grand_total
                cart.tqty       = total_qty.
            
            
            /**/
            FIND FIRST cart WHERE cart.token = tokens NO-ERROR.
            IF AVAILABLE cart THEN DO :
                FIND FIRST cartitem WHERE cartitem.cartid = cart.id NO-ERROR.
                IF AVAIL cartitem THEN DO:
                    oCart = NEW JsonObject().
                    oCart:Add('status', 200).
                    oCart:Add('message', 'Cart Found').
                    oCart:Add('id', cart.id).
                    oCart:Add('meja', cart.meja).
                    oCart:Add('token', cart.token).
                    oCart:Add('member-id', cart.member-id).
                    
                    nou = 0.                    
/*                    FOR EACH cartitem WHERE cartitem.cartid = cart.id:*/
/*                        ASSIGN                                        */
/*                            nou = nou + 1                             */
/*                            cartitem.urut = nou.                      */
/*                    END.                                              */
                    
                    aCartItem = NEW JsonArray().
                    IF token.is_reserv = YES THEN DO:
                        FOR EACH cartitem WHERE cartitem.cartid = cart.id AND
                                                cartitem.main_food = '' :                    
                            FIND FIRST tmkn WHERE tmkn.kode = cartitem.kode NO-LOCK NO-ERROR.
                            oCartItem = NEW JsonObject().
                            FIND FIRST rsvdtl WHERE rsvdtl.noreserv = token.noreserv AND rsvdtl.kode = cartitem.kode NO-ERROR.
                            IF AVAIL rsvdtl THEN DO:
                                ASSIGN
                                    qty_stock = rsvdtl.qorder - rsvdtl.qtyout.
                            END.
    
                            IF qty_stock <= 0 THEN ASSIGN cartitem.is-active = 0.
                                                    
                            ELSE IF qty_stock > 0 AND  qty_stock < cartitem.qorder THEN DO :
                                ASSIGN
                                    cartitem.qorder   = qty_stock
                                    cartitem.harga    = cartitem.shrg * qty_stock
                                    cartitem.tcharge  = cartitem.ncharge * qty_stock
                                    cartitem.ttax     = ((cartitem.shrg * cartitem.ntax) / 100 ) * qty_stock
                                    cartitem.tdisc    = ((cartitem.shrg * cartitem.ndisc) / 100) * qty_stock.
                            END.
                            
                            oCartItem:Add('id', cartitem.id).
                            oCartItem:Add('cartid', cartitem.cartid).
                            oCartItem:Add('kode', cartitem.kode).
                            oCartItem:Add('nama', tmkn.nama).
                            oCartItem:Add('is_submitted', cartitem.is_submitted).
                            oCartItem:Add('urut', cartitem.urut).
                            oCartItem:Add('qorder', cartitem.qorder).
                            oCartItem:Add('kdprice', cartitem.kdprice).
                            oCartItem:Add('harga', cartitem.harga).
                            oCartItem:Add('nharga', cartitem.shrg).
                            oCartItem:Add('tcharge', cartitem.tcharge).
                            oCartItem:Add('tdisc', cartitem.tdisc).
                            oCartItem:Add('ttax', cartitem.ttax).
                            oCartItem:Add('status', cartitem.is-active).
                            oCartItem:Add('limit', qty_stock).
                            oCartItem:Add('image', tmkn.image).
                            oCartItem:Add('ndisc', cartitem.ndisc).
                            oCartItem:Add('ncharge', cartitem.ncharge).
                            oCartItem:Add('ntax', cartitem.ntax).
                            oCartItem:Add('catat', cartitem.catat).
                            oCartItem:Add('cancel', cartitem.cancel).
                            oCartItem:Add('qty_cancel', cartitem.qty_cancel).
                            oCartItem:Add('cancel_reason', cartitem.cancel_reason).
                            
                            aOptions = NEW JsonArray().
                            FOR EACH bcartitem WHERE bcartitem.cartid = cart.id AND
                                                     bcartitem.main_food = STRING(cartitem.id) :
                                FIND FIRST tmkn WHERE tmkn.kode = bcartitem.kode NO-LOCK NO-ERROR.
                                                                  
                                    IF qty_stock > 0 AND qty_stock < bcartitem.qorder THEN DO:
                                        ASSIGN                                        
                                            bcartitem.qorder   = qty_stock
                                            bcartitem.harga    = bcartitem.shrg * qty_stock
                                            bcartitem.tcharge  = bcartitem.ncharge * qty_stock
                                            bcartitem.ttax     = ((bcartitem.shrg * bcartitem.ntax) / 100 ) * qty_stock
                                            bcartitem.tdisc    = ((bcartitem.shrg * bcartitem.ndisc) / 100) * qty_stock.
                                    END.
                                    
                                    oOptions:Add('id', bcartitem.id).
                                    oOptions:Add('cartid', bcartitem.cartid).
                                    oOptions:Add('kode', bcartitem.kode).
                                    oOptions:Add('nama', tmkn.nama).
                                    oOptions:Add('is_submitted', bcartitem.is_submitted).
                                    oOptions:Add('urut', bcartitem.urut).
                                    oOptions:Add('qorder', bcartitem.qorder).
                                    oOptions:Add('kdprice', bcartitem.kdprice).
                                    oOptions:Add('harga', bcartitem.harga).
                                    oOptions:Add('nharga', bcartitem.shrg).
                                    oOptions:Add('tcharge', bcartitem.tcharge).
                                    oOptions:Add('tdisc', bcartitem.tdisc).
                                    oOptions:Add('ttax', bcartitem.ttax).
                                    oOptions:Add('status', bcartitem.is-active).
                                    oOptions:Add('limit', qty_stock).
                                    oOptions:Add('image', tmkn.image).
                                    oOptions:Add('ndisc', bcartitem.ndisc).
                                    oOptions:Add('ncharge', bcartitem.ncharge).
                                    oOptions:Add('ntax', bcartitem.ntax).
                                    aOptions:Add(oOptions).                                
                            END.
                            
                            oCartItem:Add('options', aOptions).
                            aCartItem:Add(oCartItem).
                        END.
                    END.
                    ELSE DO:
                        FOR EACH cartitem WHERE cartitem.cartid = cart.id AND
                                                cartitem.main_food = '' :                    
                            FIND FIRST tmkn WHERE tmkn.kode = cartitem.kode NO-LOCK NO-ERROR.
                            FIND FIRST limititem WHERE limititem.kode = cartitem.kode AND limititem.sdjam = '' NO-LOCK NO-ERROR.
                            IF AVAIL limititem THEN DO:
                                oCartItem = NEW JsonObject().
        
                                ASSIGN
                                    qty_stock = limititem.qtylimit - limititem.qtyorder
                                    qty_main  = cartitem.qorder.
        
                                IF qty_stock = 0 THEN ASSIGN cartitem.is-active = 0.
                                                        
                                ELSE IF qty_stock > 0 AND  qty_stock < cartitem.qorder THEN DO :
                                    ASSIGN
                                        cartitem.qorder   = qty_stock
                                        qty_main          = qty_stock
                                        cartitem.harga    = cartitem.shrg * qty_stock
                                        cartitem.tcharge  = cartitem.ncharge * qty_stock
                                        cartitem.ttax     = ((cartitem.shrg * cartitem.ntax) / 100 ) * qty_stock
                                        cartitem.tdisc    = ((cartitem.shrg * cartitem.ndisc) / 100) * qty_stock.
                                END.
                                
                                oCartItem:Add('id', cartitem.id).
                                oCartItem:Add('cartid', cartitem.cartid).
                                oCartItem:Add('kode', cartitem.kode).
                                oCartItem:Add('nama', tmkn.nama).
                                oCartItem:Add('is_submitted', cartitem.is_submitted).
                                oCartItem:Add('urut', cartitem.urut).
                                oCartItem:Add('qorder', cartitem.qorder).
                                oCartItem:Add('kdprice', cartitem.kdprice).
                                oCartItem:Add('harga', cartitem.harga).
                                oCartItem:Add('nharga', cartitem.shrg).
                                oCartItem:Add('tcharge', cartitem.tcharge).
                                oCartItem:Add('tdisc', cartitem.tdisc).
                                oCartItem:Add('ttax', cartitem.ttax).
                                oCartItem:Add('status', cartitem.is-active).
                                oCartItem:Add('limit', qty_stock).
                                oCartItem:Add('image', tmkn.image).
                                oCartItem:Add('ndisc', cartitem.ndisc).
                                oCartItem:Add('ncharge', cartitem.ncharge).
                                oCartItem:Add('ntax', cartitem.ntax).
                                oCartItem:Add('catat', cartitem.catat).
                                oCartItem:Add('cancel', cartitem.cancel).
                                oCartItem:Add('qty_cancel', cartitem.qty_cancel).
                                oCartItem:Add('cancel_reason', cartitem.cancel_reason).
                                
                                aOptions = NEW JsonArray().
                                DO optloop = 1 TO 2:
                                    FOR EACH bcartitem WHERE bcartitem.cartid = cart.id AND
                                                             bcartitem.main_food = STRING(cartitem.id) AND
                                                             bcartitem.kode      = IF optloop = 1 THEN cartitem.opt1 ELSE cartitem.opt2 :
                                        FIND FIRST tmkn WHERE tmkn.kode = bcartitem.kode NO-LOCK NO-ERROR.
                                        FIND FIRST blimititem WHERE blimititem.kode = bcartitem.kode AND blimititem.sdjam = '' NO-LOCK NO-ERROR.
                                        IF AVAIL blimititem THEN DO:                                                                    
                                            ASSIGN
                                                qty_stock = blimititem.qtylimit - blimititem.qtyorder
                                                bcartitem.qorder = qty_main. 
                                                
                                            IF qty_stock <= 0 THEN ASSIGN bcartitem.is-active = 0.                                                              
                                                                          
                                            IF qty_stock > 0 AND qty_stock < bcartitem.qorder THEN DO:
                                                ASSIGN                                        
                                                    bcartitem.qorder   = qty_stock
                                                    bcartitem.harga    = bcartitem.shrg * qty_stock
                                                    bcartitem.tcharge  = bcartitem.ncharge * qty_stock
                                                    bcartitem.ttax     = ((bcartitem.shrg * bcartitem.ntax) / 100 ) * qty_stock
                                                    bcartitem.tdisc    = ((bcartitem.shrg * bcartitem.ndisc) / 100) * qty_stock.
                                            END.
                                        END.
                                        ELSE DO :
                                            ASSIGN
                                                qty_stock = 99
                                                bcartitem.qorder = IF bcartitem.is_submitted = NO THEN qty_main ELSE bcartitem.qorder.
                                        END.    
                                        
                                        oOptions = NEW JsonObject().
                                        oOptions:Add('id', bcartitem.id).
                                        oOptions:Add('cartid', bcartitem.cartid).
                                        oOptions:Add('kode', bcartitem.kode).
                                        oOptions:Add('nama', tmkn.nama).
                                        oOptions:Add('is_submitted', bcartitem.is_submitted).
                                        oOptions:Add('urut', bcartitem.urut).
                                        oOptions:Add('qorder', bcartitem.qorder).
                                        oOptions:Add('kdprice', bcartitem.kdprice).
                                        oOptions:Add('harga', bcartitem.harga).
                                        oOptions:Add('nharga', bcartitem.shrg).
                                        oOptions:Add('tcharge', bcartitem.tcharge).
                                        oOptions:Add('tdisc', bcartitem.tdisc).
                                        oOptions:Add('ttax', bcartitem.ttax).
                                        oOptions:Add('status', bcartitem.is-active).
                                        oOptions:Add('limit', qty_stock).
                                        oOptions:Add('image', tmkn.image).
                                        oOptions:Add('ndisc', bcartitem.ndisc).
                                        oOptions:Add('ncharge', bcartitem.ncharge).
                                        oOptions:Add('ntax', bcartitem.ntax).
                                        aOptions:Add(oOptions).                                                         
                                    END.
                                END.
                                
                                oCartItem:Add('options', aOptions).
                                aCartItem:Add(oCartItem).
                            END.
                            ELSE DO :
                                
                                oCartItem = NEW JsonObject().
                                oCartItem:Add('id', cartitem.id).
                                oCartItem:Add('cartid', cartitem.cartid).
                                oCartItem:Add('kode', cartitem.kode).
                                oCartItem:Add('nama', tmkn.nama).
                                oCartItem:Add('is_submitted', cartitem.is_submitted).
                                oCartItem:Add('urut', cartitem.urut).
                                oCartItem:Add('qorder', cartitem.qorder).
                                oCartItem:Add('kdprice', cartitem.kdprice).
                                oCartItem:Add('harga', cartitem.harga).
                                oCartItem:Add('nharga', cartitem.shrg).
                                oCartItem:Add('tcharge', cartitem.tcharge).
                                oCartItem:Add('tdisc', cartitem.tdisc).
                                oCartItem:Add('ttax', cartitem.ttax).
                                oCartItem:Add('status', cartitem.is-active).
                                oCartItem:Add('limit', 99).
                                oCartItem:Add('image', tmkn.image).
                                oCartItem:Add('ndisc', cartitem.ndisc).
                                oCartItem:Add('ncharge', cartitem.ncharge).
                                oCartItem:Add('ntax', cartitem.ntax).
                                oCartItem:Add('catat', cartitem.catat).
                                oCartItem:Add('cancel', cartitem.cancel).
                                oCartItem:Add('qty_cancel', cartitem.qty_cancel).
                                oCartItem:Add('cancel_reason', cartitem.cancel_reason).
                                
                                aOptions = NEW JsonArray().
                                DO optloop = 1 TO 2:
                                    FOR EACH bcartitem WHERE bcartitem.cartid = cart.id AND
                                                             bcartitem.main_food = STRING(cartitem.id) AND
                                                             bcartitem.kode      = IF optloop = 1 THEN cartitem.opt1 ELSE cartitem.opt2 :                                                 
                                        FIND FIRST tmkn WHERE tmkn.kode = bcartitem.kode NO-LOCK NO-ERROR.                            
                                        FIND FIRST blimititem WHERE blimititem.kode = bcartitem.kode AND blimititem.sdjam = '' NO-LOCK NO-ERROR.
                                        IF AVAIL blimititem THEN DO:
                                            ASSIGN
                                                qty_stock = blimititem.qtylimit - blimititem.qtyorder
                                                bcartitem.qorder = qty_main.
                                                
                                            IF qty_stock <= 0 THEN ASSIGN bcartitem.is-active = 0.
                                                                          
                                            IF qty_stock > 0 AND qty_stock < bcartitem.qorder THEN DO:
                                                ASSIGN                                        
                                                    bcartitem.qorder   = qty_stock
                                                    bcartitem.harga    = bcartitem.shrg * qty_stock
                                                    bcartitem.tcharge  = bcartitem.ncharge * qty_stock
                                                    bcartitem.ttax     = ((bcartitem.shrg * bcartitem.ntax) / 100 ) * qty_stock
                                                    bcartitem.tdisc    = ((bcartitem.shrg * bcartitem.ndisc) / 100) * qty_stock.
                                            END.
                                            
                                            oOptions = NEW JsonObject(). 
                                            oOptions:Add('id', bcartitem.id).                           
                                            oOptions:Add('cartid', bcartitem.cartid).
                                            oOptions:Add('kode', bcartitem.kode).
                                            oOptions:Add('nama', tmkn.nama).
                                            oOptions:Add('is_submitted', bcartitem.is_submitted).
                                            oOptions:Add('urut', bcartitem.urut).
                                            oOptions:Add('qorder', bcartitem.qorder).
                                            oOptions:Add('kdprice', bcartitem.kdprice).
                                            oOptions:Add('harga', bcartitem.harga).
                                            oOptions:Add('nharga', bcartitem.shrg).
                                            oOptions:Add('tcharge', bcartitem.tcharge).
                                            oOptions:Add('tdisc', bcartitem.tdisc).
                                            oOptions:Add('ttax', bcartitem.ttax).
                                            oOptions:Add('status', bcartitem.is-active).
                                            oOptions:Add('limit', qty_stock).
                                            oOptions:Add('image', tmkn.image).
                                            oOptions:Add('ndisc', bcartitem.ndisc).
                                            oOptions:Add('ncharge', bcartitem.ncharge).
                                            oOptions:Add('ntax', bcartitem.ntax).
                                            aOptions:Add(oOptions).
                                            
                                        END.
                                        ELSE DO:
                                            oOptions = NEW JsonObject().    
                                            oOptions:Add('id', bcartitem.id).                        
                                            oOptions:Add('cartid', bcartitem.cartid).
                                            oOptions:Add('kode', bcartitem.kode).
                                            oOptions:Add('nama', tmkn.nama).
                                            oOptions:Add('is_submitted', bcartitem.is_submitted).
                                            oOptions:Add('urut', bcartitem.urut).
                                            oOptions:Add('qorder', bcartitem.qorder).
                                            oOptions:Add('kdprice', bcartitem.kdprice).
                                            oOptions:Add('harga', bcartitem.harga).
                                            oOptions:Add('nharga', bcartitem.shrg).
                                            oOptions:Add('tcharge', bcartitem.tcharge).
                                            oOptions:Add('tdisc', bcartitem.tdisc).
                                            oOptions:Add('ttax', bcartitem.ttax).
                                            oOptions:Add('status', bcartitem.is-active).
                                            oOptions:Add('limit', 99).
                                            oOptions:Add('image', tmkn.image).
                                            oOptions:Add('ndisc', bcartitem.ndisc).
                                            oOptions:Add('ncharge', bcartitem.ncharge).
                                            oOptions:Add('ntax', bcartitem.ntax).
                                            aOptions:Add(oOptions).
                                        END.
                                    END.
                                END.
                                oCartItem:Add('options', aOptions).
                                aCartItem:Add(oCartItem).
                            END.                    
                        END.
                    END.
                    
                    oCart:Add('tcharge', cart.tcharge).
                    oCart:Add('tdisc', cart.tdisc).
                    oCart:Add('ttax', cart.ttax).
                    oCart:Add('total', cart.total).
                    oCart:Add('grand', cart.grand).
                    oCart:Add('cart_item', aCartItem).                                       
                END.  
            END.
            
            RELEASE cart.
            RELEASE cartitem.
            RELEASE rsvdtl.           
            RELEASE limititem.            
            
            
            ASSIGN
                oResponse            = NEW OpenEdge.Web.WebResponse().
              
            ASSIGN 
                lcString = oCart:GetJsonText().
                oBody = NEW OpenEdge.Core.String(lcString).
            
            ASSIGN 
                oResponse:Entity        = oCart
                oResponse:ContentType   = 'application/json':u
                oResponse:ContentLength = oBody:Size
                oResponse:StatusCode    = INTEGER(201).
            
            ASSIGN 
                oWriter = NEW WebResponseWriter(oResponse).
                oWriter:Open().
                oWriter:Close().                                
        END.
        ELSE DO :
            errorValidation(401, "Unauthorized").
        END. 
        
        RETURN 0.
            
      END METHOD.
      
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
      
      METHOD PUBLIC CHARACTER validateRequest (INPUT propertyName AS CHARACTER,
                                               INPUT dataType     AS CHARACTER,
                                               INPUT required     AS LOGICAL,  
                                               INPUT oJsonRequest AS JsonObject,
                                               OUTPUT errorMessage AS CHARACTER ):             
             
             errorMessage = "".             
                              
                          
             IF dataType = "STRING" THEN DO :
                IF oJsonRequest:Has(propertyName)
                THEN DO :                    
                    IF required = TRUE THEN DO :
                        IF oJsonRequest:IsNull(propertyName) THEN DO :
                            errorMessage = propertyName + " value is null".
                        END.
                        ELSE DO : 
                            IF oJsonRequest:GetType(propertyName) EQ JsonDataType:STRING 
                            THEN DO :
                                IF oJsonRequest:GetCharacter(propertyName) = "" THEN DO :
                                    errorMessage = propertyName + " value is null".
                                END.
                                ELSE DO:
                                    RETURN "OK".
                                END.
                            END.
                            ELSE DO :
                                    errorMessage = "Incompatible types, " + propertyName + " it must be a STRING".
                            END. 
                        END.
                    END.
                    ELSE DO :
                        IF oJsonRequest:GetType(propertyName) EQ JsonDataType:STRING 
                        THEN DO :
                            RETURN "OK".
                        END.
                        ELSE DO :
                                errorMessage = "Incompatible types, " + propertyName + " it must be a STRING".
                        END.
                    END.     
                END.
                ELSE DO :
                    errorMessage = propertyName + " property was missing!".
                END.
             END.
             ELSE IF dataType = "NUMBER" THEN DO :
                IF oJsonRequest:Has(propertyName)
                THEN DO :
                     IF required = TRUE THEN DO :
                        IF oJsonRequest:IsNull(propertyName) THEN DO :
                            errorMessage = propertyName + " value is null".
                        END.
                        ELSE DO :
                            IF oJsonRequest:GetType(propertyName) EQ JsonDataType:NUMBER 
                            THEN DO :
                                IF oJsonRequest:GetInteger(propertyName) = 0 THEN DO :
                                    errorMessage = propertyName + " value is null".
                                END.
                                ELSE DO :
                                    RETURN "OK".
                                END.
                            END.
                            ELSE DO :
                                    errorMessage = "Incompatible types, " + propertyName + " it must be a NUMBER".
                            END. 
                        END.
                    END.
                    ELSE DO :
                        IF oJsonRequest:GetType(propertyName) EQ JsonDataType:NUMBER
                        THEN DO :
                            RETURN "OK".
                        END.
                        ELSE DO :
                                errorMessage = "Incompatible types, " + propertyName + " it must be a NUMBER".
                        END.
                    END.  
                END.
                ELSE DO :
                    errorMessage = propertyName + " property was missing!".
                END.
             END.
             ELSE IF dataType = "BOOLEAN" THEN DO :
                IF oJsonRequest:Has(propertyName)
                THEN DO :
                     IF required = TRUE THEN DO :
                        IF oJsonRequest:IsNull(propertyName) THEN DO :
                            errorMessage = propertyName + " value is null".
                        END.
                        ELSE DO :
                            IF oJsonRequest:GetType(propertyName) EQ JsonDataType:BOOLEAN 
                            THEN DO :
                                    RETURN "OK".
                            END.
                            ELSE DO :
                                    errorMessage = "Incompatible types, " + propertyName + " it must be a BOOLEAN".
                            END. 
                        END.
                    END.
                    ELSE DO :
                        IF oJsonRequest:GetType(propertyName) EQ JsonDataType:BOOLEAN
                        THEN DO :
                            RETURN "OK".
                        END.
                        ELSE DO :
                                errorMessage = "Incompatible types, " + propertyName + " it must be a BOOLEAN".
                        END.
                    END.  
                END.
                ELSE DO :
                    errorMessage = propertyName + " property was missing!".
                END.
             END.
             ELSE IF dataType = "ARRAY" THEN DO :
                IF oJsonRequest:Has(propertyName)
                THEN DO :
                     IF required = TRUE THEN DO :
                        IF oJsonRequest:IsNull(propertyName) THEN DO :
                            errorMessage = propertyName + " value is null".
                        END.
                        ELSE DO :
                            IF oJsonRequest:GetType(propertyName) EQ JsonDataType:ARRAY 
                            THEN DO :
                                    RETURN "OK".
                            END.
                            ELSE DO :
                                    errorMessage = "Incompatible types, " + propertyName + " it must be an ARRAY".
                            END. 
                        END.
                    END.
                    ELSE DO :
                        IF oJsonRequest:GetType(propertyName) EQ JsonDataType:ARRAY
                        THEN DO :
                            RETURN "OK".
                        END.
                        ELSE DO :
                                errorMessage = "Incompatible types, " + propertyName + " it must be an ARRAY".
                        END.
                    END.  
                END.
                ELSE DO :
                    errorMessage = propertyName + " property was missing!".
                END.
             END.
             ELSE IF dataType = "OBJECT" THEN DO :
                IF oJsonRequest:Has(propertyName)
                THEN DO :
                     IF required = TRUE THEN DO :
                        IF oJsonRequest:IsNull(propertyName) THEN DO :
                            errorMessage = propertyName + " value is null".
                        END.
                        ELSE DO :
                            IF oJsonRequest:GetType(propertyName) EQ JsonDataType:OBJECT 
                            THEN DO :
                                    RETURN "OK".
                            END.
                            ELSE DO :
                                    errorMessage = "Incompatible types, " + propertyName + " it must be an OBJECT".
                            END. 
                        END.
                    END.
                    ELSE DO :
                        IF oJsonRequest:GetType(propertyName) EQ JsonDataType:OBJECT
                        THEN DO :
                            RETURN "OK".
                        END.
                        ELSE DO :
                                errorMessage = "Incompatible types, " + propertyName + " it must be an OBJECT".
                        END.
                    END.  
                END.
                ELSE DO :
                    errorMessage = propertyName + " property was missing!".
                END.
             END.
      END METHOD.
      
      METHOD PUBLIC CHARACTER terminateService ( INPUT errorJson AS JsonObject):
          
            DEFINE VARIABLE oResponse       AS OpenEdge.Net.HTTP.IHttpResponse  NO-UNDO.
            DEFINE VARIABLE oWriter         AS OpenEdge.Web.WebResponseWriter   NO-UNDO.
            DEFINE VARIABLE oBody           AS OpenEdge.Core.String             NO-UNDO.
            DEFINE VARIABLE oJsonObject     AS JsonObject                       NO-UNDO.
            DEFINE VARIABLE lcJsonObject    AS LONGCHAR                         NO-UNDO.
            DEFINE VARIABLE ix              AS INTEGER                          NO-UNDO.
            DEFINE VARIABLE i               AS INTEGER INITIAL 0                NO-UNDO.
             
             ASSIGN 
                    oResponse   = NEW OpenEdge.Web.WebResponse().
                
                ASSIGN
                    lcJsonObject = errorJson:GetJsonText().
                    oBody = NEW OpenEdge.Core.String(lcJsonObject).
                    
                ASSIGN
                    oResponse:Entity        = errorJson
                    oResponse:ContentType   = 'application/json':u
                    oResponse:ContentLength = oBody:Size
                    oResponse:StatusCode    = INTEGER(StatusCodeEnum:BadRequest).
                    
                ASSIGN
                    oWriter = NEW WebResponseWriter(oResponse).
                    oWriter:Open(). oWriter:Close().
                
                STOP. 
      END METHOD.
END CLASS.