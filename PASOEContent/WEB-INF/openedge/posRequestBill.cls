 
 /*------------------------------------------------------------------------
    File        : posRequestBill
    Purpose     : Modul request bill dan cetak bill sementara
    Syntax      : Progress OpenEdge12
    Description : Modul untuk submit request bill dan cetak bill sementara, 
                  dan menampilkan bill sementara ke Front End
    Author(s)   : Galih Raka Gustiawan
    Created     : Thu Jul 27 12:02:14 ICT 2023
    Notes       : METHOD yang di gunakan GET, POST
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.WebResponseWriter.
USING OpenEdge.Net.HTTP.StatusCodeEnum.
USING OpenEdge.Web.WebHandler.
USING Progress.Json.ObjectModel.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posRequestBill INHERITS WebHandler: 

    METHOD OVERRIDE PROTECTED INTEGER HandleNotAllowedMethod( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").

    END METHOD.

    METHOD OVERRIDE PROTECTED INTEGER HandleNotImplemented( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").

    END METHOD.

    
    
    /*------------------------------------------------------------------------------
            Purpose: Modul untuk menampilkan bill sementara ke FrontEnd. Services akan 
                     mengembalikan data dalam bentuk Json dan status code. Return 0 
                     berarti program berjalan tanpa ada error.                                                               
            Notes :  Menggunakan paramater token untuk mengakses services ini.                                                                       
    ------------------------------------------------------------------------------*/
     METHOD OVERRIDE PROTECTED INTEGER HandleGet( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
     
    
        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter  NO-UNDO.
        DEFINE VARIABLE oBody     AS OpenEdge.Core.String            NO-UNDO.
            
        DEFINE VARIABLE tokens              AS CHARACTER                NO-UNDO.
        DEFINE VARIABLE lcstring            AS LONGCHAR                 NO-UNDO.
        DEFINE VARIABLE jam                 AS INTEGER                  NO-UNDO.
        DEFINE VARIABLE menit               AS INTEGER                  NO-UNDO.        
        DEFINE VARIABLE expTime             AS INTEGER                  NO-UNDO.
        DEFINE VARIABLE oBill               AS JsonObject               NO-UNDO.
        DEFINE VARIABLE aItems              AS JsonArray                NO-UNDO.
        DEFINE VARIABLE oItems              AS JsonObject               NO-UNDO.
        DEFINE VARIABLE qCounter            AS INTEGER      INITIAL 0   NO-UNDO.
        
        tokens  = poRequest:GetPathParameter("token").
                    
        IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END.
        
        FIND FIRST request_bill WHERE request_bill.token = tokens NO-ERROR.
        IF AVAIL request_bill THEN DO :
            
            oBill = NEW JsonObject().
            FIND FIRST profile NO-LOCK NO-ERROR.
            IF AVAIL profile THEN DO:
                oBill:Add('company_name', profile.company).
                oBill:Add('company_address', profile.address1).
                oBill:Add('company_address2', profile.address2).
                oBill:Add('company_email', profile.email).
                oBill:Add('company_phone', profile.telp).    
            END.
            
            oBill:Add('meja', request_bill.meja).
            oBill:Add('tanggal', request_bill.tanggal).
            oBill:Add('pesanan', request_bill.pesanan).
            oBill:Add('notrans', request_bill.notrans).
            oBill:Add('status', request_bill.request_status).
            
            FIND FIRST trhdr WHERE trhdr.pesanan = request_bill.pesanan 
                               AND trhdr.notrans = request_bill.notrans 
                               AND trhdr.meja = request_bill.meja NO-ERROR.
            IF AVAIL trhdr THEN DO:
                
                IF trhdr.nobill <> '' THEN DO :
                    ASSIGN
                        trhdr.is_completed = YES.
                END.
                
                oBill:Add('is_completed', trhdr.is_completed).
                oBill:Add('nobill', trhdr.nobill).
                oBill:Add('total', trhdr.total).
                oBill:Add('service_charge', trhdr.tcharge).
                oBill:Add('tax', trhdr.ttax).
                oBill:Add('discount', trhdr.tdisc).
                oBill:Add('grand', trhdr.grand).
                oBill:Add('is_cetak', trhdr.struk).
                aItems = NEW JsonArray().
                FOR EACH trdtl WHERE trdtl.pesanan = trhdr.pesanan 
                               AND trdtl.notrans = trhdr.notrans 
                               AND trdtl.meja = trhdr.meja 
                               AND trdtl.cartid = trhdr.cartid:
                    
                    oItems = NEW JsonObject().
                    oItems:Add('nourut', trdtl.urut).
                    FIND FIRST tmkn WHERE tmkn.kode = trdtl.kode NO-LOCK NO-ERROR.
                    IF AVAIL tmkn THEN DO:
                        oItems:Add('nama', tmkn.nama).
                        oItems:Add('image', tmkn.image).    
                    END.
                    oItems:Add('quantity', trdtl.qorder).
                    oItems:Add('harga', trdtl.harga).
                    oItems:Add('type', trdtl.tipe).
                    aItems:Add(oItems).
                    
                    IF trdtl.tipe <> 'D' THEN DO:
                        qCounter = qCounter + trdtl.qorder.
                    END.
                END.
                
                oBill:Add('qcount', qCounter).
                oBill:Add('item', aItems).
            END.
        END.
        ELSE DO :
            errorValidation(401, "unauthorized").
        END.
        
        RELEASE trhdr.
        RELEASE trdtl.
        RELEASE cart.
        RELEASE profile.
        RELEASE notification.
        RELEASE tmkn.
        RELEASE request_bill.
        
        ASSIGN 
            oResponse            = NEW OpenEdge.Web.WebResponse().
               
        ASSIGN 
            lcString = oBill:GetJsonText().
            oBody = NEW OpenEdge.Core.String(lcString).
        
        ASSIGN 
            oResponse:Entity        = oBill
            oResponse:ContentType   = 'application/json':u
            oResponse:ContentLength = oBody:Size
            oResponse:StatusCode = INTEGER(StatusCodeEnum:OK).
        
        ASSIGN 
            oWriter = NEW WebResponseWriter(oResponse).
            oWriter:Open().
            oWriter:Close().
        
        RETURN 0.
        
     END METHOD. 
     
     /*------------------------------------------------------------------------------
            Purpose: Modul untuk melakukan request bill dan cetak bill sementara di kasir. 
                     mengembalikan data dalam bentuk Json dan status code. Return 0 
                     berarti program berjalan tanpa ada error.                                                               
            Notes :  Menggunakan paramater token untuk mengakses services ini.                                                                       
    ------------------------------------------------------------------------------*/
     METHOD OVERRIDE PROTECTED INTEGER HandlePost( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse    NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter     NO-UNDO.
        DEFINE VARIABLE oBody     AS OpenEdge.Core.String               NO-UNDO.
        
        DEFINE VARIABLE jsonRequest         AS JsonObject               NO-UNDO.
        DEFINE VARIABLE jsonResponse        AS JsonObject               NO-UNDO.
        DEFINE VARIABLE tokens              AS CHARACTER                NO-UNDO.
        DEFINE VARIABLE cartidx             AS INTEGER                  NO-UNDO.
        DEFINE VARIABLE counter             AS INTEGER   INITIAL 1      NO-UNDO.
        DEFINE VARIABLE jam                 AS INTEGER                  NO-UNDO.
        DEFINE VARIABLE menit               AS INTEGER                  NO-UNDO.        
        DEFINE VARIABLE expTime             AS INTEGER                  NO-UNDO.
        DEFINE VARIABLE lcstring            AS LONGCHAR                 NO-UNDO.
        
       tokens  = poRequest:GetPathParameter("token").
       
       IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END.
       
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
            
            FIND FIRST cart WHERE cart.token = token.token NO-LOCK NO-ERROR.
            IF AVAIL cart THEN DO:
                FIND FIRST trhdr WHERE trhdr.cartid = cart.id AND trhdr.meja = cart.meja AND trhdr.nobill = '' NO-LOCK NO-ERROR.
                IF AVAIL trhdr THEN DO:
                    FIND FIRST request_bill WHERE request_bill.pesanan = trhdr.pesanan AND request_bill.notrans = trhdr.notrans AND request_bill.meja = trhdr.meja NO-ERROR.
                    IF NOT AVAIL request_bill THEN DO:
                        FIND LAST request_bill NO-LOCK NO-ERROR.
                        IF AVAIL request_bill THEN DO:
                            counter = request_bill.id + 1.
                        END.
                        
                        CREATE request_bill.
                        ASSIGN 
                            request_bill.id = counter
                            request_bill.meja = trhdr.meja
                            request_bill.notrans = trhdr.notrans
                            request_bill.pesanan = trhdr.pesanan
                            request_bill.grand = trhdr.grand
                            request_bill.tanggal = STRING(TODAY, '99/99/9999') + ' ' + STRING(TIME, 'HH:MM')
                            request_bill.request_status = 'open'
                            request_bill.token = token.token.
                        
                        
                        FIND FIRST cart WHERE cart.id = trhdr.cartid NO-ERROR.
                        IF AVAIL cart THEN DO:
                            ASSIGN
                                cart.is_completed = YES.    
                        END.
                        
                        jsonResponse = NEW JsonObject().
                        jsonResponse:Add('message', 'Bill created').
                        
/*                        RUN D:\Tamani\Workspace3\api\PrintBillSementara.p (INPUT trhdr.cartid, */
/*                                                                           INPUT trhdr.pesanan,*/
/*                                                                           INPUT trhdr.meja,   */
/*                                                                           INPUT trhdr.notrans,*/
/*                                                                           INPUT trhdr.tgl,    */
/*                                                                           INPUT trhdr.kharga).*/
                    END.
                    ELSE DO:
                        errorValidation(406, 'Bill already created').
                    END.
                END.
                ELSE DO:
                    errorValidation(404, 'Resource not found').
                END.
            END.
        END.
        ELSE DO :
            errorValidation(401, 'Unauthorized').
        END.
       
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
                
        RETURN 0.      
            
      END METHOD.
      
      /*------------------------------------------------------------------------------
            Purpose:                                                                
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
       METHOD OVERRIDE PROTECTED INTEGER HandleDelete( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").        
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
      
      /*------------------------------------------------------------------------------
            Purpose: Modul untuk memvalidasi request body yang diterima oleh Services                                                               
            Notes:                                                                        
      ------------------------------------------------------------------------------*/
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
      
      /*------------------------------------------------------------------------------
            Purpose: Module untuk mengembalikan response data ke end user dalam bentuk json.                                                                
            Notes:                                                                        
      ------------------------------------------------------------------------------*/
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