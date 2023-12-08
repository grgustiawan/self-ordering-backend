 
 /*------------------------------------------------------------------------
    File        : posUpdateAfterSubmit
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : User
    Created     : Wed Jul 12 14:20:36 ICT 2023
    Notes       : 
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Net.URI.
USING OpenEdge.Net.HTTP.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posUpdateAfterSubmit INHERITS WebHandler: 

	
		
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
 	METHOD OVERRIDE PROTECTED INTEGER HandlePost( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
 	    
 	    IF NOT CONNECTED('pos') THEN DO:
            ErrorValidation(503, "Database is not connected").
        END.
 	    
 	    /*HTTP Services*/
        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse    NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter     NO-UNDO.
        DEFINE VARIABLE oBody     AS OpenEdge.Core.String               NO-UNDO.
        DEFINE VARIABLE lcString  AS LONGCHAR                           NO-UNDO.
        
        /* Request Body */
        DEFINE VARIABLE tokens  AS CHARACTER                            NO-UNDO.
        
        /* Json Data */
        DEFINE VARIABLE JsonResponse AS JsonObject                      NO-UNDO. 
        
        /* Operation Variable */
        DEFINE VARIABLE expTime     AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE jam         AS INTEGER                          NO-UNDO.
        DEFINE VARIABLE menit       AS INTEGER                          NO-UNDO.
        
        tokens = poRequest:GetPathParameter('token').
        
        FIND FIRST token WHERE token.token = tokens NO-LOCK NO-ERROR.
        IF AVAIL token THEN DO:
            IF DATE(SUBSTRING(token.expdate,1,10)) < TODAY THEN DO:
                errorValidation(401, "Token Expired").
            END.
            IF DATE(SUBSTRING(token.expdate,1,10)) = TODAY THEN DO:
                ASSIGN
                    expTime = 0
                    jam = INT(SUBSTRING(token.expdate, 12,2))
                    menit = INT(SUBSTRING(token.expdate, 15,2)).
                    
                expTime = (menit * 60) + (jam * 3600).
                IF TIME > expTime THEN DO:
                    errorValidation(401, "Token Expired").
                END.
            END.
            
            FIND FIRST cart WHERE cart.token = tokens NO-ERROR.
            IF AVAIL cart THEN DO:
                
                ASSIGN
                    cart.is_submitted = NO.
                
                RELEASE cart.
                    
                JsonResponse = NEW JsonObject().                
                JsonResponse:Add('message', 'Cart Updated' ).
                
                ASSIGN 
                    oResponse               = NEW OpenEdge.Web.WebResponse().
                                   
                ASSIGN 
                    lcString                = JsonResponse:GetJsonText().
                    oBody                   = NEW OpenEdge.Core.String(lcString).
                
                ASSIGN 
                    oResponse:Entity        = JsonResponse
                    oResponse:ContentType   = 'application/json':u
                    oResponse:ContentLength = oBody:Size
                    oResponse:StatusCode = INTEGER(StatusCodeEnum:OK).
                
                ASSIGN 
                    oWriter = NEW WebResponseWriter(oResponse).
                    oWriter:Open().
                    oWriter:Close().
            END.
                                              
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