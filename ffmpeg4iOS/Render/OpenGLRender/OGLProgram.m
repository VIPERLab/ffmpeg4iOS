//
//  OGLProgram.m
//  ffmpeg4iOS
//
//  Created by Wayne W. on 13-5-28.
//
//

#import "OGLProgram.h"
#import <OpenGLES/EAGLDrawable.h>
#import <QuartzCore/QuartzCore.h>
#import "Shaders.h"
#import "OpenGLESTexProvider.h"

@interface DEF_CLASS(OGLProgram) ()
{
    GLuint _prgrmOGL;
    CVOpenGLESTextureCacheRef _oglTexCache;
}

@property (nonatomic, assign) enum AVPixelFormat pixel_format;

- (GLuint)_buildWithFragShader:(const char *)aFrag vertexShader:(const char*)aVert;
- (GLuint)_buildShader:(const char *)source type:(GLenum)type;

@end

@implementation DEF_CLASS(OGLProgram)

- (instancetype)initWithPixFmt:(enum AVPixelFormat)pixFmt
{
    self.pixel_format = pixFmt;
    
    if (pixFmt == AV_PIX_FMT_YUV420P)
    {
        return [self initWithVertShader:VERTEX_SHADER fragShader:FRAGMENT_SHADER];
    }
    
    if (pixFmt == AV_PIX_FMT_NV12)
    {
        return [self initWithVertShader:NV12_VERTEX_SHDR fragShader:NV12_FRAGMENT_SHDR];
    }
    
    if (pixFmt == AV_PIX_FMT_UYVY422)
    {
        return [self initWithVertShader:UYVY_VERTEX_SHDR fragShader:UYVY_FRAGMENT_SHDR];
    }
    
    VERROR();
    return [super init];
}

- (id)initWithVertShader:(const char*)vertShdr fragShader:(const char*)fragShdr
{
    self = [super init];
    if (self)
    {        
        GLuint prgm = [self _buildWithFragShader:fragShdr vertexShader:vertShdr];
        if (!prgm)
        {
            VBR(0);
            self = nil;
        }
        else
        {
            _prgrmOGL = prgm;
        }
    }

    return self;
}

- (BOOL)activate
{
    if (!_prgrmOGL)
    {
        return NO;
    }
    
    glUseProgram(_prgrmOGL);
    
    if (GL_NO_ERROR == glGetError())
    {
        [self _initAttributes];
        [self _initUniforms];
        [self _initTextures];
    }
    
    return GL_NO_ERROR == glGetError();
}

- (BOOL)activateTexBuffer:(id<DEF_CLASS(YUVBuffer)>)yuvBuf oglContext:(EAGLContext*)oglCtx
{
    if ([yuvBuf pix_fmt] != self.pixel_format)
    {
        VERROR();
        return NO;
    }
    
    id<DEF_CLASS(OpenGLESTexProvider)> provider = (id<DEF_CLASS(OpenGLESTexProvider)>)yuvBuf;
    
    if ([provider conformsToProtocol:@protocol(DEF_CLASS(OpenGLESTexProvider))] &&
        [provider supportPixelFmt:self.pixel_format])
    {
        id<DEF_CLASS(OpenGLESTexProvider)> provider = (id<DEF_CLASS(OpenGLESTexProvider)>)yuvBuf;
        return [self activateTexProvider:provider
                                 context:oglCtx
                                   width:[yuvBuf width]
                                  height:[yuvBuf height]];
    }
    else if (self.pixel_format == AV_PIX_FMT_NV12)
    {
        return [self activateTexY:[yuvBuf componentY]
                               UV:[yuvBuf componentUV]
                            width:[yuvBuf width]
                           height:[yuvBuf height]];
    }
    else if (self.pixel_format == AV_PIX_FMT_YUV420P)
    {
        return [self activateTexY:[yuvBuf componentY]
                                U:[yuvBuf componentU]
                                V:[yuvBuf componentV]
                            width:[yuvBuf width]
                           height:[yuvBuf height]];
    }
    
    return NO;
}

- (BOOL)activateTexY:(const void *)bytesY
                   U:(const void *)bytesU
                   V:(const void *)bytesV
               width:(GLsizei)width
              height:(GLsizei)height
{
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.texY);
    glUniform1i(self.uniformTexY, 0);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RED_EXT,
                 width, height,
                 0,
                 GL_RED_EXT, GL_UNSIGNED_BYTE,
                 bytesY);
    VGLERR();
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, self.texU);
    glUniform1i(self.uniformTexU, 1);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RED_EXT,
                 width/2, height/2,
                 0,
                 GL_RED_EXT, GL_UNSIGNED_BYTE,
                 bytesU);
    VGLERR();
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, self.texV);
    glUniform1i(self.uniformTexV, 2);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RED_EXT,
                 width/2, height/2,
                 0,
                 GL_RED_EXT, GL_UNSIGNED_BYTE,
                 bytesV);
    VGLERR();
    
    return GL_NO_ERROR == glGetError();
}

- (BOOL)activateTexY:(const void *)bytesY
                  UV:(const void *)bytesUV
               width:(GLsizei)width
              height:(GLsizei)height
{
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.texY);
    glUniform1i(self.uniformTexY, 0);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RED_EXT,
                 width, height,
                 0,
                 GL_RED_EXT, GL_UNSIGNED_BYTE,
                 bytesY);
    VGLERR();
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, self.texUV);
    glUniform1i(self.uniformTexUV, 1);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RG_EXT,
                 width/2, height/2,
                 0,
                 GL_RG_EXT, GL_UNSIGNED_BYTE,
                 bytesUV);
    VGLERR();
    
    return GL_NO_ERROR == glGetError();
}

- (BOOL)activateTexProvider:(id<DEF_CLASS(OpenGLESTexProvider)>)provider
                    context:(EAGLContext*)oglCtx
                      width:(GLsizei)width
                     height:(GLsizei)height
{
    BOOL ret = YES;
    CVReturn err = kCVReturnSuccess;
    GLuint texY = 0;
    GLuint texUV = 0;
    
    CPRA(oglCtx);
    
    if (!_oglTexCache)
    {
        // remove textures
        [self _cleanup];
        
        err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, oglCtx, NULL, &_oglTexCache);
    }
    CPRA(_oglTexCache);
    
    // flush
    CVOpenGLESTextureCacheFlush(_oglTexCache, 0);
    
    // Y
    glActiveTexture(GL_TEXTURE0);
    texY = [provider ogl_texY4cache:_oglTexCache];
    CBRA(texY);
    self.texY = texY;
    glUniform1i(self.uniformTexY, 0);
    VGLERR();
    
    // UV
    glActiveTexture(GL_TEXTURE1);
    texUV = [provider ogl_texUV4cache:_oglTexCache];
    CBRA(texUV);
    self.texUV = texUV;
    glUniform1i(self.uniformTexUV, 1);
    VGLERR();
    
    CBRA(texY && texUV);
    VBR(self.texY == texY);
    VBR(self.texUV == texUV);
    
ERROR:
    if (!ret)
    {
        VERROR();
        [self _cleanup];
    }
    
    return ret;
}



- (void)dealloc
{
    if (_oglTexCache)
    {
        CFRelease(_oglTexCache);
        _oglTexCache = NULL;
    }
    
    [self _cleanup];
}

#pragma mark private
- (GLuint)_buildWithFragShader:(const char *)aFrag vertexShader:(const char*)aVert
{
    GLuint shdrVert = [self _buildShader:aVert type:GL_VERTEX_SHADER];
    GLuint shdrFrag = [self _buildShader:aFrag type:GL_FRAGMENT_SHADER];
    
    GLuint prog = glCreateProgram();
    glAttachShader(prog, shdrVert);
    glAttachShader(prog, shdrFrag);
    glLinkProgram(prog);
    
    GLint ret;
    glGetProgramiv(prog, GL_LINK_STATUS, &ret);
    if (GL_FALSE == ret)
    {
        assert(0);
        exit(1);
    }
    
    return prog;
}

- (GLuint)_buildShader:(const char *)source type:(GLenum)type
{
    GLuint shdr = glCreateShader(type);
    glShaderSource(shdr, 1, &source, NULL);
    glCompileShader(shdr);
    
    GLint compileRet;
    glGetShaderiv(shdr, GL_COMPILE_STATUS, &compileRet);
    if (GL_FALSE == compileRet)
    {
        assert(0);
        exit(1);
    }
    
    return shdr;
}

- (void)_initAttributes
{
    // locate the position attribute, see vert shader
    self.slotPosition = glGetAttribLocation(_prgrmOGL, "position");
    VGLERR();
    glEnableVertexAttribArray(_slotPosition);
    VGLERR();
    
    // locate the TexCoordIn attribute, see vert shader
    self.slotTexCoordIn = glGetAttribLocation(_prgrmOGL, "TexCoordIn");
    VGLERR();
    glEnableVertexAttribArray(_slotTexCoordIn);
    VGLERR();
}

- (void)_initUniforms
{
    // locate the texture uniforms, see frag shader
    self.uniformTexY = glGetUniformLocation(_prgrmOGL, "videoFrameY");
    VGLERR();
    
    if (self.pixel_format == AV_PIX_FMT_YUV420P)
    {
        self.uniformTexU = glGetUniformLocation(_prgrmOGL, "videoFrameU");
        self.uniformTexV = glGetUniformLocation(_prgrmOGL, "videoFrameV");
        VGLERR();
    }
    else if (self.pixel_format == AV_PIX_FMT_NV12 ||
             self.pixel_format == AV_PIX_FMT_UYVY422)
    {
        self.uniformTexUV = glGetUniformLocation(_prgrmOGL, "videoFrameUV");
        VGLERR();
    }
    else
    {
        VERROR();
    }
}

- (BOOL)_initTextures
{
    self.texY = [self _initTexture:GL_TEXTURE0];
    
    if (self.pixel_format == AV_PIX_FMT_YUV420P)
    {
        self.texU = [self _initTexture:GL_TEXTURE1];
        self.texV = [self _initTexture:GL_TEXTURE2];
    }
    else if (self.pixel_format == AV_PIX_FMT_NV12 ||
             self.pixel_format == AV_PIX_FMT_UYVY422)
    {
        self.texUV = [self _initTexture:GL_TEXTURE1];
    }
    else
    {
        VERROR();
    }
    
    return GL_NO_ERROR == glGetError();
}

- (GLuint)_initTexture:(GLenum)tex
{
    GLuint ret;
    
    glGenTextures(1, &ret);
    glActiveTexture(tex);
    glBindTexture(GL_TEXTURE_2D, ret);
    VGLERR();
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    VGLERR();
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    VGLERR();
    
    glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE ); // IMPORTANT!!
    glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
    VGLERR();
    
    return ret;
}

- (void)_destroyTex:(GLuint*)tex
{
    if (tex && *tex)
    {
        glDeleteTextures(1, tex);
        *tex = NULL;
    }
}

- (void)_cleanup
{
    [self _destroyTex:&_texY];
    [self _destroyTex:&_texU];
    [self _destroyTex:&_texV];
    [self _destroyTex:&_texUV];
}

@end
