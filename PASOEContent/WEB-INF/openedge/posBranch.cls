 
 /*------------------------------------------------------------------------
    File        : posBranch
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : User
    Created     : Wed Jul 05 12:59:36 ICT 2023
    Notes       : 
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.WebResponseWriter.
USING OpenEdge.Net.HTTP.StatusCodeEnum.
USING OpenEdge.Web.WebHandler.
USING Progress.Json.ObjectModel.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posBranch INHERITS WebHandler: 

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
     
    
        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter  NO-UNDO.
        DEFINE VARIABLE oBody     AS OpenEdge.Core.String            NO-UNDO.
        
        DEFINE VARIABLE oBranch   AS JsonObject                      NO-UNDO.
        DEFINE VARIABLE tokens    AS CHARACTER                       NO-UNDO.
        DEFINE VARIABLE lcString  AS LONGCHAR                        NO-UNDO.
        
        DEFINE VARIABLE expTime   AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE menit     AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE jam       AS INTEGER                         NO-UNDO.
        
        tokens = poRequest:GetPathParameter('token').
        
        IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END.
        
        FIND FIRST token WHERE token.token = tokens NO-LOCK NO-ERROR.
        IF AVAIL  token THEN DO:
            
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
            
            
            FIND FIRST profile WHERE profile.kdcab = token.kdcab NO-LOCK NO-ERROR.
            IF AVAIL profile THEN DO:
                oBranch = NEW JsonObject().
                oBranch:Add('company_name', profile.company).
                oBranch:Add('email', profile.email).
                oBranch:Add('table', token.meja).
                oBranch:Add('address', profile.address1).
                
                ASSIGN 
                    oResponse            = NEW OpenEdge.Web.WebResponse().
                               
                ASSIGN 
                    lcString = oBranch:GetJsonText()
                    oBody = NEW OpenEdge.Core.String(lcString).
                
                ASSIGN 
                    oResponse:Entity        = oBranch
                    oResponse:ContentType   = 'application/json':u
                    oResponse:ContentLength = oBody:Size
                    oResponse:StatusCode    = INTEGER(StatusCodeEnum:OK).
                    
                ASSIGN 
                oWriter = NEW WebResponseWriter(oResponse).
                oWriter:Open().
                oWriter:Close().
            END.
            ELSE DO:
                errorValidation(404, "Store not found").
            END.
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