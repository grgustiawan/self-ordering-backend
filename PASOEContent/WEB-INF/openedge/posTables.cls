 
 /*------------------------------------------------------------------------
    File        : posTables
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : resto
    Created     : Mon Nov 20 10:31:32 ICT 2023
    Notes       : 
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.WebResponseWriter.
USING OpenEdge.Net.HTTP.StatusCodeEnum.
USING OpenEdge.Web.WebHandler.
USING Progress.Json.ObjectModel.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posTables INHERITS WebHandler: 

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
     
        DEFINE VARIABLE oResponse           AS OpenEdge.Net.HTTP.IHttpResponse  NO-UNDO.
        DEFINE VARIABLE oWriter             AS OpenEdge.Web.WebResponseWriter   NO-UNDO.
        DEFINE VARIABLE oBody               AS OpenEdge.Core.String             NO-UNDO.
        
        DEFINE VARIABLE oTable              AS JsonObject                       NO-UNDO.
        DEFINE VARIABLE aTable              AS JsonArray                        NO-UNDO.
        DEFINE VARIABLE lcString            AS LONGCHAR                         NO-UNDO.
        DEFINE VARIABLE jam                 AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE menit               AS INTEGER                          NO-UNDO.        
        DEFINE VARIABLE expTime             AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE tokens              AS CHARACTER                        NO-UNDO.
        
        tokens = poRequest:GetPathParameter('token').
        
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
        END.
        
        aTable = NEW JsonArray().
        FOR EACH nmeja NO-LOCK:
            oTable = NEW JsonObject().
            oTable:Add('nomeja', nmeja.kdmeja).
            oTable:Add('kondisi', nmeja.kondisi).
            oTable:Add('lantai', nmeja.lantai).
            oTable:Add('urut', nmeja.urut).
            aTable:Add(oTable).
        END.
            
        ASSIGN 
            oResponse            = NEW OpenEdge.Web.WebResponse().

        ASSIGN 
            lcString = aTable:GetJsonText()
            oBody = NEW OpenEdge.Core.String(lcString).
        
        ASSIGN 
            oResponse:Entity        = aTable
            oResponse:ContentType   = 'application/json':u
            oResponse:ContentLength = oBody:Size
            oResponse:StatusCode    = INTEGER(StatusCodeEnum:OK).
        
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
     METHOD OVERRIDE PROTECTED INTEGER HandlePost( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").      
      END METHOD.
      
      /*------------------------------------------------------------------------------
            Purpose:                                                                
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
       METHOD OVERRIDE PROTECTED INTEGER HandleDelete( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").        
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