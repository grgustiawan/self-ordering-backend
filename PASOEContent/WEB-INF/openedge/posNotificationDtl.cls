 
 /*------------------------------------------------------------------------
    File        : posNotificationDtl
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : User
    Created     : Fri Jul 14 13:06:52 ICT 2023
    Notes       : 
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Net.URI.
USING OpenEdge.Net.HTTP.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posNotificationDtl INHERITS WebHandler: 

	
		
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
        
        DEFINE VARIABLE aNotif    AS JsonArray                       NO-UNDO.
        DEFINE VARIABLE oNotif    AS JsonObject                      NO-UNDO.
        
        DEFINE VARIABLE tokens    AS CHARACTER                       NO-UNDO.
        DEFINE VARIABLE expTime   AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE jam       AS INTEGER                         NO-UNDO.
        DEFINE VARIABLE menit     AS INTEGER                         NO-UNDO.
        
        tokens = poRequest:GetPathParameter('token').
        
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
            
            aNotif = NEW JsonArray().
            FIND FIRST cart WHERE cart.token = tokens NO-LOCK NO-ERROR.
            IF AVAIL cart THEN DO:
                FOR EACH notification WHERE notification.cartid = cart.id:
                    notification.is_open = YES.
                    oNotif = NEW JsonObject().
                    oNotif:Add('id', notification.id).
                    oNotif:Add('cartid', notification.cartid).
                    oNotif:Add('titles', notification.titles).
                    oNotif:Add('msg', notification.msg).
                    oNotif:Add('crDate', notification.crdate).
                    oNotif:Add('priority', notification.priority).
                    oNotif:Add('is_open', notification.is_open).
                    aNotif:Add(oNotif).
                END.
            END.            
                
            ASSIGN 
                oResponse               = NEW OpenEdge.Web.WebResponse().
                           
            ASSIGN 
                lcString                = aNotif:GetJsonText().
                oBody                   = NEW OpenEdge.Core.String(lcString).
            
            ASSIGN 
                oResponse:Entity        = aNotif
                oResponse:ContentType   = 'application/json':u
                oResponse:ContentLength = oBody:Size
                oResponse:StatusCode = INTEGER(StatusCodeEnum:OK).
            
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