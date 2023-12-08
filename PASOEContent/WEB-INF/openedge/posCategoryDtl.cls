 
 /*------------------------------------------------------------------------
    File        : posCategoryDtl
    Purpose     : Get single category
    Syntax      : Progress OE 12
    Description : Get single category using nogrp parameter with nested relation with food
    Author(s)   : Galih Raka Gustiawan
    Created     : Tue Jun 13 17:23:34 ICT 2023
    Notes       : Services name http://host:port/api/web/category/:nogrp/tokens/:token
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Net.URI.
USING OpenEdge.Net.HTTP.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posCategoryDtl INHERITS WebHandler: 
    
    DEFINE TEMP-TABLE tCategory NO-UNDO
        FIELD nogrp     AS INTEGER
        FIELD remark    AS CHARACTER
        FIELD images    AS CHARACTER
        FIELD descriptions  AS CHARACTER.

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
     
    
        DEFINE VARIABLE oResponse   AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.
        DEFINE VARIABLE oWriter     AS OpenEdge.Web.WebResponseWriter  NO-UNDO.
        DEFINE VARIABLE oBody       AS OpenEdge.Core.String            NO-UNDO.
            
        DEFINE VARIABLE oCategory   AS JsonObject                      NO-UNDO.
        DEFINE VARIABLE aItem       AS JsonArray                       NO-UNDO.
        DEFINE VARIABLE oItem       AS JsonObject                      NO-UNDO.
        DEFINE VARIABLE lcString    AS LONGCHAR                        NO-UNDO.
        
        DEFINE VARIABLE id          AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE tokens      AS CHARACTER                       NO-UNDO.        
        DEFINE VARIABLE expTime     AS INTEGER                         NO-UNDO.        
        DEFINE VARIABLE jam         AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE menit       AS INTEGER                         NO-UNDO.        
        DEFINE VARIABLE qty_stock   AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE qty_order   AS INTEGER                         NO-UNDO.
        
        id = INTEGER(poRequest:GetPathParameter("nogrp")).
        tokens  = poRequest:GetPathParameter("token"). 
        
        IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END.
        
        IF id = 210 OR id = 220 OR id = 130 THEN DO:
            errorValidation(406, "Not Acceptable").
        END.
        
        FIND FIRST token WHERE token.token = tokens NO-LOCK NO-ERROR.
        IF AVAIL token THEN DO :
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
                FOR EACH rsvdtl WHERE rsvdtl.noreserv = token.noreserv:
                    FIND FIRST btndtl1 WHERE btndtl1.kode = rsvdtl.kode NO-LOCK NO-ERROR.
                    IF AVAIL btndtl1 THEN DO:
                        FIND FIRST btnhdr WHERE btnhdr.nogrp = btndtl1.nogrp NO-LOCK NO-ERROR.
                        IF AVAIL btnhdr THEN DO:
                            CREATE tCategory.
                            ASSIGN
                                tCategory.nogrp  = btnhdr.nogrp
                                tCategory.remark = btnhdr.remark
                                tCategory.images = btnhdr.image
                                tCategory.descriptions = btnhdr.description. 
                        END.
                    END.
                END.
                
                FIND FIRST tCategory WHERE tCategory.nogrp = id NO-LOCK NO-ERROR.
                IF AVAIL tCategory THEN DO:
                    oCategory = NEW JsonObject().
                    oCategory:Add('id', tCategory.nogrp).
                    oCategory:Add('name', tCategory.remark).
                    oCategory:Add('description', tCategory.description).
                    oCategory:Add('image', tCategory.images).
                    
                    aItem = NEW JsonArray().
                    FOR EACH rsvdtl WHERE rsvdtl.noreserv = token.noreserv NO-LOCK:
                        FIND FIRST btndtl1 WHERE btndtl1.kode = rsvdtl.kode AND btndtl1.nogrp = tCategory.nogrp NO-LOCK NO-ERROR.
                        IF AVAIL btndtl1 THEN DO:
                            FIND FIRST tmkn WHERE tmkn.kode = btndtl1.kode NO-LOCK NO-ERROR.
                            IF AVAIL tmkn THEN DO:
                                oItem = NEW JsonObject().
                                oItem:Add('id', btndtl1.kode).
                                oItem:Add('name', btndtl1.nama).
                                oItem:Add('description', btndtl1.description).
                                
                                IF btndtl1.kdprice = 'P01' THEN DO :
                                    oItem:Add('price', tmkn.hjual1).    
                                END.
                                ELSE IF btndtl1.kdprice = 'P02' THEN DO :
                                    oItem:Add('price', tmkn.hjual2).    
                                END.
                                ELSE IF btndtl1.kdprice = 'P03' THEN DO :
                                    oItem:Add('price', tmkn.hjual3).    
                                END.
                                
                                oItem:Add('service_charge', btndtl1.ncharge).
                                oItem:Add('discount', btndtl1.ndisc).
                                oItem:Add('tax', btndtl1.ntax).  
                                oItem:Add('image', tmkn.image).
                                
                                FIND FIRST cart WHERE cart.token = tokens NO-LOCK NO-ERROR.
                                IF AVAIL cart THEN DO:
                                    FIND FIRST cartitem WHERE cartitem.cartid = cart.id AND cartitem.kode = btndtl1.kode NO-LOCK NO-ERROR.
                                    IF AVAIL cartitem THEN DO:
                                        qty_order = cartitem.qorder.
                                    END.
                                    ELSE qty_order = 0.       
                                END.
                                ELSE qty_order = 0.
                                
                                qty_stock = rsvdtl.qorder - qty_order.
                                IF qty_stock <= 0 THEN DO:
                                    qty_stock = 0.
                                END.
                                
                                oItem:Add('quantity', qty_stock).
                                aItem:Add(oItem).
                            END.
                        END.
                    END.
                    oCategory:Add('menu', aItem).
                END.
                ELSE DO:
                    errorvalidation(404, "Category Not Found").
                END.
            END.
            ELSE DO:
                FIND FIRST btnhdr WHERE btnhdr.nogrp = id NO-LOCK NO-ERROR.
                IF AVAIL btnhdr THEN DO:
                    oCategory = NEW JsonObject().
                    oCategory:Add('id', btnhdr.nogrp).
                    oCategory:Add('name', btnhdr.remark).
                    oCategory:Add('description', btnhdr.description).
                    oCategory:Add('image', btnhdr.image).
                    
                    aItem = NEW JsonArray().
                    FOR EACH btndtl1 WHERE btndtl1.nogrp = btnhdr.nogrp NO-LOCK:
                        FIND FIRST tmkn WHERE tmkn.kode = btndtl1.kode NO-LOCK NO-ERROR.
                        IF AVAIL tmkn THEN DO:
                            oItem = NEW JsonObject().
                            oItem:Add('id', btndtl1.kode).
                            oItem:Add('name', btndtl1.nama).
                            oItem:Add('description', btndtl1.description).
                            
                            IF btndtl1.kdprice = 'P01' THEN DO :
                                oItem:Add('price', tmkn.hjual1).    
                            END.
                            ELSE IF btndtl1.kdprice = 'P02' THEN DO :
                                oItem:Add('price', tmkn.hjual2).    
                            END.
                            ELSE IF btndtl1.kdprice = 'P03' THEN DO :
                                oItem:Add('price', tmkn.hjual3).    
                            END.
                            
                            oItem:Add('service_charge', btndtl1.ncharge).
                            oItem:Add('discount', btndtl1.ndisc).
                            oItem:Add('tax', btndtl1.ntax).  
                            oItem:Add('image', tmkn.image).
                            
                            qty_stock = 99.
                            FOR FIRST limititem WHERE limititem.kode = btndtl1.kode AND limititem.sdjam = "" NO-LOCK:
                                qty_stock = limititem.qtylimit - limititem.qtyorder.
                            END.
                            
                            oItem:Add('quantity', qty_stock).
                            aItem:Add(oItem).
                        END.
                    END.
                    oCategory:Add('menu', aItem).
                END.
                ELSE DO:
                    errorvalidation(404, "Category Not Found").
                END.
            END.
            
            ASSIGN 
                oResponse            = NEW OpenEdge.Web.WebResponse().
                           
            ASSIGN 
                lcString = oCategory:GetJsonText().
                oBody = NEW OpenEdge.Core.String(lcString).
            
            ASSIGN 
                oResponse:Entity        = oCategory
                oResponse:ContentType   = 'application/json':u
                oResponse:ContentLength = oBody:Size
                oResponse:StatusCode    = INTEGER(StatusCodeEnum:OK).
            
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