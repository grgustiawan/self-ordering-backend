 
 /*------------------------------------------------------------------------
    File        : posMenuDtl
    Purpose     : Get single menu by kode
    Syntax      : Progress OE 12
    Description : Get single menu nested with option relation using kode parameter
    Author(s)   : Galih Raka Gustiawan
    Created     : Tue Jun 13 17:20:14 ICT 2023
    Notes       : Services name http://host:port/api/web/menu/:kode/tokens/:token
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Net.URI.
USING OpenEdge.Net.HTTP.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posMenuDtl INHERITS WebHandler: 

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
        
        DEFINE VARIABLE oMenu       AS JsonObject                       NO-UNDO.
        DEFINE VARIABLE aOption     AS JsonArray                        NO-UNDO.
        DEFINE VARIABLE oOption     AS JsonObject                       NO-UNDO.
        
        DEFINE VARIABLE id          AS CHARACTER                        NO-UNDO.                        
        DEFINE VARIABLE tokens      AS CHARACTER                        NO-UNDO.        
        DEFINE VARIABLE expTime     AS INTEGER                          NO-UNDO.        
        DEFINE VARIABLE jam         AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE menit       AS INTEGER                          NO-UNDO.        
        DEFINE VARIABLE quantity    AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE qty_order   AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE opt_quantity AS INTEGER                         NO-UNDO.
        
        id      = poRequest:GetPathParameter("kode").
        tokens  = poRequest:GetPathParameter("token").
        
        IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
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
            
            FIND FIRST btndtl1 WHERE btndtl1.kode = id NO-LOCK NO-ERROR.
            IF AVAIL btndtl1 THEN DO :
                FIND FIRST tmkn WHERE tmkn.kode = btndtl1.kode NO-LOCK NO-ERROR.
                IF AVAIL tmkn THEN DO:
                    
                    IF token.is_reserv = YES THEN DO:
                        FIND FIRST rsvdtl WHERE rsvdtl.noreserv = token.noreserv AND rsvdtl.kode = id NO-LOCK NO-ERROR.
                        IF AVAILABLE rsvdtl THEN DO:
                            quantity = rsvdtl.qorder - rsvdtl.qtyout.
                            IF quantity <= 0 THEN DO:
                                quantity = 0.
                            END.
                        END.
                    END.
                    ELSE DO:
                        FIND FIRST limititem WHERE limititem.kode = tmkn.kode AND limititem.sdjam = '' NO-LOCK NO-ERROR.
                        IF AVAIL limititem THEN DO:
                            quantity = limititem.qtylimit - limititem.qtyorder.
                        END.
                        ELSE DO:
                            quantity = 99. 
                        END.
                    END.
                    
                    oMenu = NEW JsonObject().
                    oMenu:Add('id', btndtl1.kode).
                    oMenu:Add('name', btndtl1.nama).
                    oMenu:Add('description', btndtl1.description).
                    FIND FIRST btnhdr WHERE btnhdr.nogrp = btndtl1.nogrp NO-LOCK NO-ERROR.
                    IF AVAIL  btnhdr THEN DO:
                        oMenu:Add('category', btnhdr.remark).
                    END.
                    ELSE DO:
                        oMenu:Add('category', '').
                    END.
                    
                    IF btndtl1.kdprice = 'P01' THEN DO :
                        oMenu:Add('price', tmkn.hjual1).    
                    END.
                    ELSE IF btndtl1.kdprice = 'P02' THEN DO :
                        oMenu:Add('price', tmkn.hjual2).    
                    END.
                    ELSE IF btndtl1.kdprice = 'P03' THEN DO :
                        oMenu:Add('price', tmkn.hjual3).    
                    END.
                    
                    oMenu:Add('service_charge', btndtl1.ncharge).
                    oMenu:Add('discount', btndtl1.ndisc).
                    oMenu:Add('tax', btndtl1.ntax).
                    oMenu:Add('quantity', quantity).
                    oMenu:Add('opt1_name', btndtl1.ketopt1).
                    oMenu:Add('opt2_name', btndtl1.ketopt2).  
                    oMenu:Add('image', tmkn.image).
                    
                    aOption = NEW JsonArray().
                    FOR EACH btndtl2 WHERE btndtl2.kode = btndtl1.kode NO-LOCK:
                        FIND FIRST tmkn WHERE tmkn.kode = btndtl2.kodedtl NO-LOCK NO-ERROR.
                        IF AVAIL tmkn THEN DO :
                            FIND FIRST limititem WHERE limititem.kode = tmkn.kode AND limititem.sdjam = '' NO-LOCK NO-ERROR.
                            IF AVAIL limititem THEN DO:
                                opt_quantity = limititem.qtylimit - limititem.qtyorder.
                            END.
                            ELSE DO:
                                opt_quantity = 99. 
                            END.
                            
                            oOption = NEW JsonObject().
                            oOption:Add('id', btndtl2.kodedtl).
                            oOption:Add('name', btndtl2.namadtl).
                            oOption:Add('description', btndtl2.description).
                            
                            IF btndtl2.kdprice = 'P01' THEN DO :
                                oOption:Add('price', tmkn.hjual1).    
                            END.
                            ELSE IF btndtl2.kdprice = 'P02' THEN DO :
                                oOption:Add('price', tmkn.hjual2).    
                            END.
                            ELSE IF btndtl2.kdprice = 'P03' THEN DO :
                                oOption:Add('price', tmkn.hjual3).    
                            END.
                            
                            oOption:Add('service_charge', btndtl2.ncharge).
                            oOption:Add('discount', btndtl2.ndisc).
                            oOption:Add('tax', btndtl2.ntax).
                            oOption:Add('quantity', opt_quantity).
                            oOption:Add('image', tmkn.image).
                            oOption:Add('opt', btndtl2.noopt).
                            aOption:Add(oOption).
                        END.
                    END.
                    
                    IF btndtl1.nama MATCHES "*STEAK*" THEN DO:
                        oMenu:Add('is_steak', YES).
                    END.
                    ELSE DO:
                        oMenu:Add('is_steak', NO).
                    END.
                    
                    oMenu:Add('option', aOption).
                    
                    ASSIGN 
                        oResponse               = NEW OpenEdge.Web.WebResponse().
                                       
                    ASSIGN 
                        lcString                = oMenu:GetJsonText().
                        oBody                   = NEW OpenEdge.Core.String(lcString).
                    
                    ASSIGN 
                        oResponse:Entity        = oMenu
                        oResponse:ContentType   = 'application/json':u
                        oResponse:ContentLength = oBody:Size
                        oResponse:StatusCode = INTEGER(StatusCodeEnum:OK).
                    
                    ASSIGN 
                        oWriter = NEW WebResponseWriter(oResponse).
                        oWriter:Open().
                        oWriter:Close().
                    
                    RETURN 0.
                END.
            END.
            ELSE DO:
                errorValidation(404, "Menu not found").
            END.
        END.
        ELSE DO :
            errorValidation(401, "Unauthorized").
        END.
        
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