 
 /*------------------------------------------------------------------------
    File        : posHomeValidation
    Purpose     : Validating token
    Syntax      : Progress OE 12 
    Description :  
    Author(s)   : User
    Created     : Thu Jul 06 15:25:52 ICT 2023
    Notes       : Services name http://host:port/api/web/home/:token
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.WebResponseWriter.
USING OpenEdge.Net.HTTP.StatusCodeEnum.
USING OpenEdge.Web.WebHandler.
USING Progress.Json.ObjectModel.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posHomeValidation INHERITS WebHandler: 

	
		
	/*------------------------------------------------------------------------------
            Purpose: Handler for unsupported methods. The request being serviced and
            		 an optional status code is returned. A zero or null value means 
            		 this method will deal with all errors.                                                               
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
	METHOD OVERRIDE PROTECTED INTEGER HandleNotAllowedMethod( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
	
		/* Throwing an error from this method results in a 500/Internal Server Error response. 
        The web handler will attempt to log this exception.
 	    
        See the HandleGet method's comments on choosing a value to return from this method. */
        	
		UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").
	END METHOD.


	/*------------------------------------------------------------------------------
            Purpose: Handler for unknown methods. The request being serviced and an 
                     optional status code is returned. A zero or null value means 
                     this method will deal with all errors.                                                               
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
	METHOD OVERRIDE PROTECTED INTEGER HandleNotImplemented( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
	
		/* Throwing an error from this method results in a 500/Internal Server Error response. 
        The web handler will attempt to log this exception.
 	    
        See the HandleGet method's comments on choosing a value to return from this method. */	
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
        DEFINE VARIABLE lcString  AS LONGCHAR                        NO-UNDO.
        
        DEFINE VARIABLE jsonResponse    AS JsonObject                           NO-UNDO.    
            
        DEFINE VARIABLE tokens    AS CHARACTER                       NO-UNDO.
                
        DEFINE VARIABLE menit     AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE jam       AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE expTime   AS INTEGER                         NO-UNDO.        
        
        tokens = poRequest:GetPathParameter("token").
        
        IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END.
                
        FIND FIRST token WHERE token.token = tokens NO-LOCK NO-ERROR.
        IF AVAIL token THEN DO:
                FIND FIRST profile WHERE profile.kdcab = token.kdcab NO-LOCK NO-ERROR.
                /* Validasi Waktu Expired */                            
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
                
                jsonResponse = NEW JsonObject().
                jsonResponse:Add('message', 'Token Is Valid').
                jsonResponse:Add('kdcab', token.kdcab).
                jsonResponse:Add('meja', token.meja).
                jsonResponse:Add('token', token.token).
                jsonResponse:Add('member_id', token.member-id).
                jsonResponse:Add('company', profile.company).
                                          
                
                ASSIGN
                    oResponse = NEW OpenEdge.Web.WebResponse().
                    
                ASSIGN 
                    lcString = jsonResponse:GetJsonText()
                    oBody = NEW OpenEdge.Core.String(lcString).
                    
                ASSIGN 
                    oResponse:Entity        = jsonResponse
                    oResponse:ContentType   = 'application/json':u
                    oResponse:ContentLength = oBody:Size
                    oResponse:StatusCode    = INTEGER(200).
                    
                    
                ASSIGN 
                    oWriter = NEW WebResponseWriter(oResponse).
                    oWriter:Open().
                    oWriter:Close().
                                
        END.
        ELSE DO:
            errorvalidation(401, "Unauthorized").
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