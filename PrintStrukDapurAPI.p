ROUTINE-LEVEL ON ERROR UNDO, THROW.
DEFINE INPUT PARAMETER iToken AS CHARACTER NO-UNDO.

DEFINE VARIABLE sid         AS INTEGER INITIAL 1 NO-UNDO.
DEFINE VARIABLE hid         AS INTEGER INITIAL 1 NO-UNDO.
DEFINE VARIABLE xprinter    AS CHARACTER         NO-UNDO.
DEFINE VARIABLE branch      AS CHARACTER         NO-UNDO.
DEFINE VARIABLE address     AS CHARACTER         NO-UNDO.
DEFINE VARIABLE meja        AS CHARACTER         NO-UNDO.
DEFINE VARIABLE oPrint      AS LOGICAL           NO-UNDO.
DEFINE VARIABLE lcFileToPrint   AS LONGCHAR      NO-UNDO.

DEFINE BUFFER bcartitem FOR cartitem.
    
DEFINE TEMP-TABLE hstruk NO-UNDO
        FIELD id        AS INTEGER
        FIELD tprn1     AS CHARACTER
        FIELD tpdevice  AS CHARACTER
        FIELD tmeja     AS CHARACTER.
        
DEFINE TEMP-TABLE struk NO-UNDO
        FIELD id        AS INTEGER
        FIELD tkode     AS CHARACTER
        FIELD tmeja     AS CHARACTER
        FIELD tnama     AS CHARACTER
        FIELD tprice    AS DECIMAL
        FIELD tqorder   AS INTEGER
        FIELD tprn1     AS CHARACTER
        FIELD tcatat    AS CHARACTER
        FIELD ttipe     AS CHARACTER
        FIELD tcartid   AS INTEGER
        FIELD tpesanan  AS CHARACTER
        FIELD tnotrans  AS INTEGER
        INDEX X id ASC.   

FIND FIRST cart WHERE cart.token = iToken NO-LOCK NO-ERROR.
FIND FIRST trhdr WHERE trhdr.cartid = cart.id AND trhdr.meja = cart.meja AND trhdr.nobill = '' NO-ERROR.
FOR EACH trdtl WHERE trdtl.cartid = trhdr.cartid AND trdtl.meja = trhdr.meja AND trdtl.notrans = trhdr.notrans AND trdtl.pesanan = trhdr.pesanan:
    FIND FIRST tmkn WHERE tmkn.kode = trdtl.kode NO-ERROR.
    IF AVAIL tmkn THEN
    DO:
        CREATE struk.
        ASSIGN
            struk.id = sid
            struk.tkode = trdtl.kode
            struk.tmeja = trdtl.meja
            struk.tnama = tmkn.nama
            struk.tprice = trdtl.harga
            struk.tqorder = trdtl.qorder
            struk.tprn1 = tmkn.prn1
            struk.tcatat = trdtl.catat
            struk.ttipe = trdtl.tipe
            struk.tcartid = trdtl.cartid
            struk.tpesanan = trdtl.pesanan
            struk.tnotrans = trdtl.notrans
            sid = sid + 1.
    END.
END.

FOR EACH struk BREAK BY tprn1:
    IF FIRST-OF(tprn1) THEN
    DO:
        FIND FIRST tprn WHERE tprn.pcode = struk.tprn1 NO-ERROR.
        IF AVAIL tprn THEN
        DO:
            CREATE hstruk.
            ASSIGN
                hstruk.id   = hid
                hstruk.tprn1 = struk.tprn1
                hstruk.tpdevice = tprn.pdevice
                hstruk.tmeja = struk.tmeja.
                hid = hid + 1.
        END.
    END.
END.

DO:    
    FOR EACH hstruk NO-LOCK:
        OUTPUT TO "D:\temp\struk.txt".
        FIND FIRST profile NO-LOCK NO-WAIT NO-ERROR.
        IF AVAIL profile THEN
        DO:
            PUT UNFORMATTED profile.company SKIP.
            PUT UNFORMATTED profile.address1 SKIP(1).
        END.
        PUT UNFORMATTED "!0Meja: " + hstruk.tmeja SKIP.
        PUT UNFORMATTED "@" SKIP.
        PUT UNFORMATTED "Tanggal : " + STRING(TODAY, "99/99/9999") SKIP.
        PUT UNFORMATTED "Jam     : " + STRING(TIME, "HH:MM:SS") SKIP.
        PUT UNFORMATTED "Usher   : Self Ordering System" SKIP.
        PUT UNFORMATTED "==================================" SKIP.
        PUT UNFORMATTED "!!Tambahan" SKIP.
        
        FOR EACH struk WHERE struk.tprn1 = hstruk.tprn1 NO-LOCK:
            FIND FIRST cartitem WHERE cartitem.cartid = struk.tcartid AND 
                       cartitem.kode = struk.tkode AND
                       cartitem.main_food = '' NO-ERROR.
            IF AVAIL cartitem THEN
            DO:
                IF cartitem.main_food = ''  THEN DO: 
                    PUT UNFORMATTED "!X    " + STRING(struk.tqorder) + "  " + struk.tnama SKIP.
                    IF struk.tcatat <> '' THEN
                    DO:
                        PUT UNFORMATTED 'r!       (' + struk.tcatat + ')' SKIP.
                    END.
                END.
                FOR EACH bcartitem WHERE bcartitem.cartid = cartitem.cartid AND bcartitem.main_food = STRING(cartitem.id):
                    FIND FIRST tmkn WHERE tmkn.kode = bcartitem.kode NO-ERROR.
                    IF AVAIL tmkn THEN
                    DO:
                        PUT UNFORMATTED "!X       " + STRING(bcartitem.qorder) + "  " + tmkn.nama SKIP.
                    END.
                END.
            END.
        END.
        
        PUT UNFORMATTED "@" SKIP.
        OUTPUT CLOSE.
        
       /* OS-COMMAND NO-WAIT VALUE("print /d:" + STRING(hstruk.tpdevice) + " D:\temp\struk.txt").
        OS-DELETE VALUE("D:\temp\struk.txt"). */
    END. 
END.

CATCH mySysError AS Progress.Lang.SysError:
   MESSAGE "Error message : " + mySysError:GetMessage(1) SKIP.
END CATCH.