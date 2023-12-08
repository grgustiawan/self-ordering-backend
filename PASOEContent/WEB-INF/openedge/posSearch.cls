 
 /*------------------------------------------------------------------------
    File        : posSearch
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : User
    Created     : Thu Jun 15 16:34:03 ICT 2023
    Notes       : 
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Net.URI.
USING OpenEdge.Net.HTTP.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posSearch INHERITS WebHandler: 

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
     
        DEFINE VARIABLE oResponse   AS OpenEdge.Net.HTTP.IHttpResponse  NO-UNDO.
        DEFINE VARIABLE oWriter     AS OpenEdge.Web.WebResponseWriter   NO-UNDO.
        DEFINE VARIABLE oBody       AS OpenEdge.Core.String             NO-UNDO.
        DEFINE VARIABLE lcString    AS LONGCHAR                         NO-UNDO.
            
        /* Json Data */
        DEFINE VARIABLE aMenu       AS JsonArray                        NO-UNDO.
        DEFINE VARIABLE oMenu       AS JsonObject                       NO-UNDO.

        /* Operation Variable */
        DEFINE VARIABLE searchVal   AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE tokens      AS CHARACTER                        NO-UNDO.        
        DEFINE VARIABLE expTime     AS INTEGER                          NO-UNDO.        
        DEFINE VARIABLE jam         AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE menit       AS INTEGER                          NO-UNDO.        
        DEFINE VARIABLE qty_stock   AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE ix          AS INTEGER                          NO-UNDO.
        
        searchVal = '*' + poRequest:GetPathParameter('name') + '*'.
        tokens  = poRequest:GetPathParameter("token").
        
        IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END.
        
        FIND FIRST token WHERE token.token = tokens NO-LOCK.
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
                aMenu = NEW JsonArray().
                FOR EACH rsvdtl WHERE rsvdtl.noreserv = token.noreserv NO-LOCK:
                    FOR EACH btndtl1 WHERE btndtl1.kode = rsvdtl.kode AND 
                                           btndtl1.nama MATCHES searchVal AND 
                                           btndtl1.nogrp <> 210 AND
                                           btndtl1.nogrp <> 220 NO-LOCK:
                        oMenu = NEW JsonObject().
                        FIND FIRST tmkn WHERE tmkn.kode = btndtl1.kode NO-LOCK.
                        IF AVAIL tmkn THEN DO:
                           
                            oMenu:Add('id', btndtl1.kode).
                            oMenu:Add('name', btndtl1.nama).
                            oMenu:Add('image', tmkn.image).
                        END.                        
                        
                        qty_stock = rsvdtl.qorder - rsvdtl.qtyout.
                        IF qty_stock <= 0 THEN DO:
                            qty_stock = 0.    
                        END.
                        
                        oMenu:Add('quantity', qty_stock).
                        aMenu:Add(oMenu).
                        qty_stock = 0.
                    END.
                END.
            END.
            ELSE DO:
                aMenu = NEW JsonArray().
                FOR EACH btndtl1 WHERE btndtl1.nama MATCHES searchVal AND
                                       btndtl1.nogrp <> 210 AND
                                       btndtl1.nogrp <> 220 NO-LOCK:
                    oMenu = NEW JsonObject().
                    FIND FIRST tmkn WHERE tmkn.kode = btndtl1.kode NO-LOCK.
                    IF AVAIL tmkn THEN DO:
                        oMenu:Add('id', btndtl1.kode).
                        oMenu:Add('name', btndtl1.nama).
                        oMenu:Add('image', tmkn.image).
                    END.
                    
                    qty_stock = 99.
                    FOR FIRST limititem WHERE limititem.kode = btndtl1.kode AND limititem.sdjam = "" NO-LOCK:
                        qty_stock = limititem.qtylimit - limititem.qtyorder.
                    END.
                    
                    oMenu:Add('quantity', qty_stock).
                    aMenu:Add(oMenu).
                END.
            END.
            
            ASSIGN 
                oResponse               = NEW OpenEdge.Web.WebResponse().
                               
            ASSIGN 
                lcString                = aMenu:GetJsonText().
                oBody                   = NEW OpenEdge.Core.String(lcString).
            
            ASSIGN 
                oResponse:Entity        = aMenu
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