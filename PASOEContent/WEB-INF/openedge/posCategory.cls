 
 /*------------------------------------------------------------------------
    File        : posCategory
    Purpose     : Get All Categories
    Syntax      : Progress OE 12
    Description : Get all categories
    Author(s)   : Galih Raka Gustiawan
    Created     : Tue Jun 13 17:07:58 ICT 2023
    Notes       : Services name http://host:port/api/web/categories/:token
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Net.URI.
USING OpenEdge.Net.HTTP.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posCategory INHERITS WebHandler: 
    
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
     
    
        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse    NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter     NO-UNDO.
        DEFINE VARIABLE oBody     AS OpenEdge.Core.String               NO-UNDO.
            
        DEFINE VARIABLE oCat        AS JsonObject                       NO-UNDO.    
        DEFINE VARIABLE aCategory   AS JsonArray                        NO-UNDO.
        DEFINE VARIABLE oCategory   AS JsonObject                       NO-UNDO.
        DEFINE VARIABLE lcString    AS LONGCHAR                         NO-UNDO.
        
        DEFINE VARIABLE tokens      AS CHARACTER                        NO-UNDO.        
        DEFINE VARIABLE jam         AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE menit       AS INTEGER                          NO-UNDO.        
        DEFINE VARIABLE expTime     AS INTEGER                          NO-UNDO.
                
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
            
            
            oCat = NEW JsonObject().
            oCat:Add('is_reserv', token.is_reserv).
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
                
                aCategory = NEW JsonArray().
                FOR EACH tCategory BREAK BY tCategory.nogrp:
                    IF FIRST-OF(tCategory.nogrp) THEN DO:
                        oCategory = NEW JsonObject().
                        oCategory:Add('id', tCategory.nogrp).
                        oCategory:Add('name', tCategory.remark).
                        oCategory:Add('description', tCategory.description).
                        oCategory:Add('image', tCategory.images).
                        aCategory:Add(oCategory).
                    END.    
                END.
            END.
            ELSE DO:
                aCategory = NEW JsonArray().
                FOR EACH btnhdr WHERE btnhdr.nogrp <> 210 AND btnhdr.nogrp <> 220 AND btnhdr.nogrp <> 130 NO-LOCK:
                    oCategory = NEW JsonObject().
                    oCategory:Add('id', btnhdr.nogrp).
                    oCategory:Add('name', btnhdr.remark).
                    oCategory:Add('description', btnhdr.description).
                    oCategory:Add('image', btnhdr.image).
                    aCategory:Add(oCategory).    
                END.
            END.
            oCat:Add('categories', aCategory).
            
            RELEASE rsvdtl.
            RELEASE btndtl1.
            RELEASE btnhdr.
            EMPTY TEMP-TABLE tCategory.
            
            
            ASSIGN 
                oResponse            = NEW OpenEdge.Web.WebResponse().
                           
            ASSIGN 
                lcString = oCat:GetJsonText().
                oBody = NEW OpenEdge.Core.String(lcString).
            
            ASSIGN 
                oResponse:Entity        = oCat
                oResponse:ContentType   = 'application/json':u
                oResponse:ContentLength = oBody:Size
                oResponse:StatusCode    = INTEGER(StatusCodeEnum:OK).
            
            ASSIGN 
                oWriter = NEW WebResponseWriter(oResponse).
                oWriter:Open().
                oWriter:Close().
        END.
        ELSE DO:
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