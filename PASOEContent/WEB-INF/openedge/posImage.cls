 
 /*------------------------------------------------------------------------
    File        : posImage
    Purpose     : GET AND POST IMAGE
    Syntax      : Progress OE12
    Description : Open Image In Browser and Upload Image to Server.
    Author(s)   : Galih Raka Gustiawan
    Created     : Wed Aug 23 10:39:35 ICT 2023
    Notes       : 
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING Progress.Json.ObjectModel.*.
USING OpenEdge.Web.WebResponseWriter.
USING OpenEdge.Net.HTTP.StatusCodeEnum.
USING OpenEdge.Web.WebHandler.
USING OpenEdge.Web.WebResponse.
USING OpenEdge.Net.MultipartEntity.
USING OpenEdge.Net.*.
USING OpenEdge.Core.*.
USING OpenEdge.Net.HTTP.*.
USING OpenEdge.Net.HTTP.Filter.Payload.*.
USING OpenEdge.Net.HTTP.Filter.Writer.EntityWriterBuilder.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS posImage INHERITS WebHandler: 
    DEFINE VARIABLE cFileName AS CHAR NO-UNDO.

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
        DEFINE VARIABLE oBody       AS OpenEdge.Core.Memptr             NO-UNDO.
        DEFINE VARIABLE ompBody     AS OpenEdge.Net.MultipartEntity     NO-UNDO.
        DEFINE VARIABLE oResHeader  AS OpenEdge.Net.HTTP.HttpHeader     NO-UNDO.
        DEFINE VARIABLE mImage      AS MEMPTR                           NO-UNDO.
        DEFINE VARIABLE path        AS CHARACTER                        NO-UNDO.
        DEFINE VARIABLE imageName   AS CHARACTER                        NO-UNDO.
        
        imageName = poRequest:GetPathParameter('id').
        path = "D:\tamani\images\" + imageName.
        
        COPY-LOB FROM FILE path TO mImage.
        oResHeader = NEW OpenEdge.Net.HTTP.HttpHeader("Content-Disposition", "inline; filename=downloaded-images.png").
        oBody = NEW OpenEdge.Core.Memptr(mImage).
             
      ASSIGN 
            oResponse            = NEW OpenEdge.Web.WebResponse()
            oResponse:StatusCode = INTEGER(StatusCodeEnum:OK)
            oResponse:Entity     = oBody
            oResponse:ContentType = 'image/png'.
       
      ASSIGN 
            oWriter = NEW WebResponseWriter(oResponse).
            oWriter:OPEN().
            oWriter:CLOSE().
        
      RETURN 0.
        
     END METHOD.
     
       
     /*------------------------------------------------------------------------------
            Purpose:                                                                
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
     METHOD OVERRIDE PROTECTED INTEGER HandlePost( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        DEFINE VARIABLE lcBody          AS LONGCHAR                NO-UNDO. 
        DEFINE VARIABLE lStatus         AS LOG                     NO-UNDO. 
        DEFINE VARIABLE joResponse      AS JsonObject              NO-UNDO. 
        DEFINE VARIABLE oResponse       AS OpenEdge.Net.HTTP.IHttpResponse  NO-UNDO. 
        DEFINE VARIABLE oWriter         AS OpenEdge.Web.WebResponseWriter   NO-UNDO. 
        DEFINE VARIABLE oEntityWriter   AS MessageWriter           NO-UNDO. 
        DEFINE VARIABLE oEntity         AS MultipartEntity         NO-UNDO. 
        DEFINE VARIABLE oPart           AS MessagePart             NO-UNDO. 
        DEFINE VARIABLE oBody           AS Progress.Lang.Object    NO-UNDO. 
        DEFINE VARIABLE oHeader         AS HttpHeader              NO-UNDO.
        
        /*Check if Request body is multipart type*/
        IF MimeTypeHelper:IsMultipart(poRequest:ContentType) THEN DO: 
            oEntityWriter = EntityWriterBuilder:Build(poRequest):Writer. 
            oEntityWriter:Open(). 
            oEntityWriter:Write(poRequest:Entity). 
            oEntityWriter:Close(). 
            
            ASSIGN oEntity = CAST(oEntityWriter:Entity, MultipartEntity) 
            oPart = oEntity:GetPart(1) 
            oHeader = oPart:Headers:Get('Content-Disposition':u) 
            THIS-OBJECT:cFileName = TRIM(oHeader:GetParameterValue('filename':u), '"'). 
            ASSIGN oBody = oEntityWriter:Entity.  
        END.
        
        /*Writing File local disk*/
        WriteFile(poRequest, oBody).

        /*Return success response*/
        joResponse = NEW JsonObject().
        joResponse:Add('status', 'success'). 
        joResponse:Add("filename", THIS-OBJECT:cFileName). 
        lcBody = joResponse:GetJsonText(). 
        
        oResponse   = NEW OpenEdge.Web.WebResponse().
        ASSIGN 
            oResponse:StatusCode = IF lStatus THEN 200 ELSE 400 
            oResponse:StatusCode = 200 
            oResponse:ContentType = "application/json":U. 
        
        oWriter = NEW WebResponseWriter(oResponse).
        oWriter:open().
        oWriter:write(lcBody).
        oWriter:flush().
        oWriter:close(). 
        
        RETURN 0.
              
      END METHOD.
      
      METHOD PRIVATE VOID WriteFile(INPUT poRequest AS OpenEdge.Web.IWebRequest, INPUT oBody AS Object): 
            
            DEFINE VARIABLE oResponseMemptrEntity   AS OpenEdge.Core.Memptr     NO-UNDO. 
            DEFINE VARIABLE oByteBucket             AS OpenEdge.Core.ByteBucket NO-UNDO.
            DEFINE VARIABLE Cnt             AS INTEGER              NO-UNDO. 
            DEFINE VARIABLE lcBody          AS LONGCHAR             NO-UNDO. 
            DEFINE VARIABLE oData           AS Object               NO-UNDO. 
            DEFINE VARIABLE oEntity         AS Object               NO-UNDO. 
            DEFINE VARIABLE mpEntity        AS MultipartEntity      NO-UNDO. 
            DEFINE VARIABLE msgPart         AS MessagePart          NO-UNDO. 
            DEFINE VARIABLE oEntityWriter   AS MessageWriter        NO-UNDO. 
            DEFINE VARIABLE cChar           AS CHARACTER            NO-UNDO.
            DEFINE VARIABLE path            AS CHARACTER            NO-UNDO.
            FIX-CODEPAGE(lcBody) = 'UTF-8':u. 
            
            // loop through multipart form body and string the parts together. 
            mpEntity = CAST(oBody, MultipartEntity). 
            DO cnt = 1 TO mpEntity:Size: 
            ASSIGN msgPart = mpEntity:GetPart(cnt). 
            
            // string the body parts together 
            oEntityWriter = NEW BinaryEntityWriter().
            
            IF TYPE-OF(oEntityWriter, ISupportEncoding) THEN          
                ASSIGN CAST(oEntityWriter, ISupportEncoding):Encoding = 'UTF-8':u.
            ELSE 
                       
            oEntityWriter:Open(). 
            oEntityWriter:Write(msgPart:Body). 
            oEntityWriter:Close(). 
    
            // Get the binary file 
            oByteBucket = CAST(oEntityWriter:entity, ByteBucket).
            oResponseMemptrEntity = oByteBucket:GetBytes().
            
            path = "D:\Tamani\images\" + STRING(THIS-OBJECT:cFileName).
            COPY-LOB FROM oResponseMemptrEntity:Value TO FILE path.
            IF VALID-OBJECT(oEntityWriter) THEN DELETE OBJECT oEntityWriter. 
            END.
             
            CATCH ewErr AS Progress.Lang.Error: 
                  MESSAGE ewErr:GetMessage(1).
            END CATCH. 
      END METHOD.
      
      /*------------------------------------------------------------------------------
            Purpose:                                                                
            Notes:                                                                        
    ------------------------------------------------------------------------------*/
      METHOD OVERRIDE PROTECTED INTEGER HandleDelete( INPUT poRequest AS OpenEdge.Web.IWebRequest ):
        
        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").        
      END METHOD.
      
    
END CLASS.