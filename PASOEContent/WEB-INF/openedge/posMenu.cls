 
 /*------------------------------------------------------------------------
    File        : posMenu
    Purpose     : Get All Food Menu
    Syntax      : Progress OE 12
    Description : Get All Food Menu
    Author(s)   : Galih Raka Gustiawan
    Created     : Tue Jun 13 16:26:37 ICT 2023
    Notes       : Services name http://host:port/api/web/menus/:token
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Net.URI.
USING OpenEdge.Net.HTTP.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posMenu INHERITS WebHandler: 

    METHOD OVERRIDE PROTECTED INTEGER HandleNotAllowedMethod( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").

    END METHOD.

    METHOD OVERRIDE PROTECTED INTEGER HandleNotImplemented( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").

    END METHOD.
    
    /*------------------------------------------------------------------------------
            Purpose: Default handler for the HTTP GET method. The request being 
                     serviced and an optional status code is returned. A zero or 
                     null value means this method will deal with all errors.                                                               
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
     METHOD OVERRIDE PROTECTED INTEGER HandleGet( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
     
        /* HTTP Service*/
        DEFINE VARIABLE oResponse   AS OpenEdge.Net.HTTP.IHttpResponse  NO-UNDO.
        DEFINE VARIABLE oWriter     AS OpenEdge.Web.WebResponseWriter   NO-UNDO.
        DEFINE VARIABLE oBody       AS OpenEdge.Core.String             NO-UNDO.
        DEFINE VARIABLE lcString    AS LONGCHAR                         NO-UNDO.
        
        /* Json Data */
        DEFINE VARIABLE oFood       AS JsonObject                       NO-UNDO.
        DEFINE VARIABLE aMenu       AS JsonArray                        NO-UNDO.
        DEFINE VARIABLE oMenu       AS JsonObject                       NO-UNDO.

        /* Operation Variable */
        DEFINE VARIABLE tokens      AS CHARACTER                        NO-UNDO.        
        DEFINE VARIABLE expTime     AS INTEGER                          NO-UNDO.       
        DEFINE VARIABLE jam         AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE menit       AS INTEGER                          NO-UNDO.        
        DEFINE VARIABLE qty_stock   AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE qty_order   AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE ix          AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE cOpt        AS INTEGER         INITIAL 0        NO-UNDO.
        
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
            
            IF token.is_reserv = YES THEN DO:
                FIND FIRST rsvhdr WHERE rsvhdr.noreserv = token.noreserv NO-LOCK NO-ERROR.
                IF AVAIL rsvhdr THEN DO:
                    oFood   = NEW JsonObject().
                    oFood:Add('is_reserv', token.is_reserv).
                    oFood:Add('noreserv', token.noreserv).
                    oFood:Add('reserv_name', rsvhdr.atasnama).
                    oFood:Add('reserv_people', rsvhdr.jumorang).
                    aMenu = NEW JsonArray().
                    FOR EACH rsvdtl WHERE rsvdtl.noreserv = token.noreserv NO-LOCK:
                        FIND FIRST btndtl1 WHERE btndtl1.kode = rsvdtl.kode NO-LOCK NO-ERROR.
                        IF AVAIL btndtl1 THEN DO:
                            oMenu = NEW JsonObject().
                            FIND FIRST tmkn WHERE tmkn.kode = btndtl1.kode NO-LOCK NO-ERROR.
                            IF AVAIL tmkn THEN DO:
                                                    
                                oMenu:Add('id', btndtl1.kode).
                                oMenu:Add('name', btndtl1.nama).
                                FIND FIRST btnhdr WHERE btnhdr.nogrp = btndtl1.nogrp NO-LOCK NO-ERROR.
                                IF AVAIL  btnhdr THEN DO:
                                    oMenu:Add('category', btnhdr.remark).
                                END.
                                ELSE DO:
                                    oMenu:Add('category', '').
                                END.
                                oMenu:Add('description', btndtl1.description).
            
                                IF btndtl1.kdprice = 'P01' THEN DO :
                                    oMenu:Add('price', tmkn.hjual1).
                                END.
                                ELSE IF btndtl1.kdprice = 'P02' THEN DO :
                                    oMenu:Add('price', tmkn.hjual2).
                                END.
                                ELSE IF btndtl1.kdprice = 'P03' THEN DO :
                                    oMenu:Add('price', tmkn.hjual3). 
                                END.
                                
                                FOR EACH btndtl2 WHERE btndtl2.kode = btndtl1.kode:
                                    cOpt = cOpt + 1.
                                END. 
            
                                oMenu:Add('option', cOpt).
                                oMenu:Add('service_charge', btndtl1.ncharge).
                                oMenu:Add('discount', btndtl1.ndisc).
                                oMenu:Add('tax', btndtl1.ntax).
                                oMenu:Add('weekday', btndtl1.weekdays).
                                oMenu:Add('image', tmkn.image).
                                cOpt = 0.
                            END.
                            
                            qty_stock = rsvdtl.qorder - rsvdtl.qtyout.
                            IF qty_stock <= 0 THEN DO:
                                qty_stock = 0.
                            END.
                            
                            oMenu:Add('quantity', qty_stock).
                            aMenu:Add(oMenu).
                        END.
                    END.
                    oFood:Add('food', aMenu).
                END.
            END.
            ELSE DO :
                oFood   = NEW JsonObject().
                oFood:Add('is_reserv', token.is_reserv).
                aMenu = NEW JsonArray().
                FOR EACH btndtl1 WHERE btndtl1.nogrp <> 210 AND btndtl1.nogrp <> 220 AND btndtl1.nogrp <> 130 NO-LOCK:
                    oMenu = NEW JsonObject().
                    FIND FIRST tmkn WHERE tmkn.kode = btndtl1.kode NO-LOCK NO-ERROR.
                    IF AVAIL tmkn THEN DO:
                                            
                        oMenu:Add('id', btndtl1.kode).
                        oMenu:Add('name', btndtl1.nama).
                        FIND FIRST btnhdr WHERE btnhdr.nogrp = btndtl1.nogrp NO-LOCK NO-ERROR.
                        IF AVAIL  btnhdr THEN DO:
                            oMenu:Add('category', btnhdr.remark).
                        END.
                        ELSE DO:
                            oMenu:Add('category', '').
                        END.
                        oMenu:Add('description', btndtl1.description).
    
                        IF btndtl1.kdprice = 'P01' THEN DO :
                            oMenu:Add('price', tmkn.hjual1).
                        END.
                        ELSE IF btndtl1.kdprice = 'P02' THEN DO :
                            oMenu:Add('price', tmkn.hjual2).
                        END.
                        ELSE IF btndtl1.kdprice = 'P03' THEN DO :
                            oMenu:Add('price', tmkn.hjual3). 
                        END. 
                        
                        FOR EACH btndtl2 WHERE btndtl2.kode = btndtl1.kode NO-LOCK:
                            cOpt = cOpt + 1.
                        END. 
    
                        oMenu:Add('option', cOpt).
                        oMenu:Add('service_charge', btndtl1.ncharge).
                        oMenu:Add('discount', btndtl1.ndisc).
                        oMenu:Add('tax', btndtl1.ntax).
                        oMenu:Add('weekday', btndtl1.weekdays).
                        oMenu:Add('image', tmkn.image).
                        cOpt = 0.
                    END.
                   
                    
                    qty_stock = 99.
                    FOR FIRST limititem WHERE limititem.kode = btndtl1.kode AND limititem.sdjam = "" NO-LOCK:
                        qty_stock = limititem.qtylimit - limititem.qtyorder.
                    END.
                    
                    oMenu:Add('quantity', qty_stock).
                    aMenu:Add(oMenu).
                END.
                oFood:Add('food', aMenu).
            END.
            
            ASSIGN 
                oResponse               = NEW OpenEdge.Web.WebResponse().
                               
            ASSIGN 
                lcString                = oFood:GetJsonText().
                oBody                   = NEW OpenEdge.Core.String(lcString).
            
            ASSIGN 
                oResponse:Entity        = oFood
                oResponse:ContentType   = 'application/json':u
                oResponse:ContentLength = oBody:Size
                oResponse:StatusCode = INTEGER(StatusCodeEnum:OK).
            
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
END CLASS.