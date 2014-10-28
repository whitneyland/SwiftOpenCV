//
//  ImageProcessing.m
//  OCR-Example
//
//  Based on: http://stackoverflow.com/questions/11624694/what-is-the-ideal-image-for-tesseract-library

#import "ImageWrapper.h"
#include <stack>
#include  <vector>

@implementation ImageWrapper

@synthesize image;
@synthesize ownsImage;

+ (ImageWrapper *) imageWithCPPImage:(Image *) theImage;
{
    ImageWrapper *wrapper = [[ImageWrapper alloc] init];
    wrapper.image=theImage;
    wrapper.ownsImage=true;
    return wrapper;
}

+ (ImageWrapper *) imageWithCPPImage:(Image *) theImage ownsImage:(bool) ownsTheImage;
{
    ImageWrapper *wrapper = [[ImageWrapper alloc] init];
    wrapper.image=theImage;
    wrapper.ownsImage=ownsTheImage;
    return wrapper;
}

@end

void Image::initYptrs() {
    m_yptrs=(uint8_t **) malloc(sizeof(uint8_t *)*m_height);
    for(int i=0; i<m_height; i++) {
        m_yptrs[i]=m_imageData+i*m_width;
    }
}


Image::Image(ImageWrapper *other, int x1, int y1, int x2, int y2) {
    m_width=x2-x1;
    m_height=y2-y1;
    m_imageData=(uint8_t *) malloc(m_width*m_height);
    initYptrs();
    Image *otherImage=other.image;
    for(int y=y1; y<y2; y++) {
        for(int x=x1; x<x2; x++) {
            (*this)[y-y1][x-x1]=(*otherImage)[y][x];
        }
    }
    m_ownsData=true;
}

Image::Image(int width, int height) {
    m_imageData=(uint8_t *) malloc(width*height);
    m_width=width;
    m_height=height;
    m_ownsData=true;
    initYptrs();
}
// create an image from data
Image::Image(uint8_t *imageData, int width, int height, bool ownsData) {
    m_imageData=imageData;
    m_width=width;
    m_height=height;
    m_ownsData=ownsData;
    initYptrs();
}

Image::Image(UIImage *srcImage, int width, int height,  CGInterpolationQuality interpolation, bool imageIsRotatedBy90degrees) {
    if(imageIsRotatedBy90degrees) {
        int tmp=width;
        width=height;
        height=tmp;
    }
    m_width=width;
    m_height=height;
    // get hold of the image bytes
    m_imageData=(uint8_t *) malloc(m_width*m_height);
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceGray();
    CGContextRef context=CGBitmapContextCreate(m_imageData,  m_width, m_height, 8, m_width, colorSpace, kCGImageAlphaNone);
    CGContextSetInterpolationQuality(context, interpolation);
    CGContextSetShouldAntialias(context, NO);
    CGContextDrawImage(context, CGRectMake(0,0, m_width, m_height), [srcImage CGImage]);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    if(imageIsRotatedBy90degrees) {
        uint8_t *tmpImage=(uint8_t *) malloc(m_width*m_height);
        for(int y=0; y<m_height; y++) {
            for(int x=0; x<m_width; x++) {
                tmpImage[x*m_height+y]=m_imageData[(m_height-y-1)*m_width+x];
            }
        }
        int tmp=m_width;
        m_width=m_height;
        m_height=tmp;
        free(m_imageData);
        m_imageData=tmpImage;
    }
    initYptrs();
}

void Image::normalise() {
    int min=INT_MAX;
    int max=0;
    
    for(int i=0; i<m_width*m_height; i++) {
        if(m_imageData[i]>max) max=m_imageData[i];
        if(m_imageData[i]<min) min=m_imageData[i];
    }
    for(int i=0; i<m_width*m_height; i++) {
        m_imageData[i]=255*(m_imageData[i]-min)/(max-min);
    }
}


// copy a section of another image
ImageWrapper *Image::createImage(ImageWrapper *other, int x1, int y1, int x2, int y2)
{
    return [ImageWrapper imageWithCPPImage:new Image(other, x1, y1, x2, y2)];
}
// create an empty image of the required width and height
ImageWrapper *Image::createImage(int width, int height) {
    return [ImageWrapper imageWithCPPImage:new Image(width, height)];
}
// create an image from data
ImageWrapper *Image::createImage(uint8_t *imageData, int width, int height, bool ownsData) {
    return [ImageWrapper imageWithCPPImage:new Image(imageData, width, height, ownsData)];
}
// take a source UIImage and convert it to greyscale
ImageWrapper *Image::createImage(UIImage *srcImage, int width, int height, bool imageIsRotatedBy90degrees) {
    return [ImageWrapper imageWithCPPImage:new Image(srcImage, width, height, kCGInterpolationHigh, imageIsRotatedBy90degrees)];
}

void Image::extractConnectedRegion(int x, int y, std::vector<ImagePoint> *points) {
    (*points).push_back(ImagePoint(x,y));
    (*this)[y][x]=0;
    int left, right;
    left=x-1;
    right=x+1;
    while(left>=0 && (*this)[y][left]!=0) {
        (*this)[y][left]=0;
        (*points).push_back(ImagePoint(left,y));
        left--;
    }
    while(right<m_width && (*this)[y][right]!=0) {
        (*this)[y][right]=0;
        (*points).push_back(ImagePoint(right,y));
        right++;
    }
    for(int i=left; i<=right; i++) {
        if(i>=0 && i<m_width) {
            if(y>0 && (*this)[y-1][i]!=0) {
                extractConnectedRegion(i, y-1, points);
            }
            if(y<(m_height-1) && (*this)[y+1][i]!=0) {
                extractConnectedRegion(i, y+1, points);
            }
        }
    }
}

inline int findThresholdAtPosition(int startx, int starty, int size, Image* src) {
    int total=0;
    for(int y=starty; y<starty+size; y++) {
        for(int x=startx; x<startx+size; x++) {
            total+=(*src)[y][x];
        }
    }
    int threshold=total/(size*size);
    return threshold;
};

/*
 ImageWrapper* Image::autoLocalThreshold() {
 const int local_size=10;
 // now produce the thresholded image
 Image *result=new Image(m_width, m_height);
 // process the image
 int threshold=0;
 for(int y=local_size/2; y<m_height-local_size/2; y++) {
 for(int x=local_size/2; x<m_width-local_size/2; x++) {
 threshold=findThresholdAtPosition(x-local_size/2, y-local_size/2, local_size, this);
 int val=(*this)[y][x];
 if(val>threshold*0.9)
 (*result)[y][x]=0;
 else
 (*result)[y][x]=255;
 }
 }
 return [ImageWrapper imageWithCPPImage:result];
 }
 */


ImageWrapper* Image::autoLocalThreshold() {
    const int local_size=8;
    // now produce the thresholded image
    uint8_t *result=(uint8_t*) malloc(m_width*m_height);
    // get the initial total
    int total=0;
    for(int y=0; y<local_size; y++) {
        for(int x=0; x<local_size; x++) {
            total+=(*this)[y][x];
        }
    }
    // process the image
    int lastIndex=m_width*m_height-(m_width*local_size/2+local_size/2);
    for(int index=m_width*local_size/2+local_size/2; index<lastIndex; index++) {
        int threshold=total/64;
        if(m_imageData[index]>threshold*0.9)
            result[index]=0;
        else
            result[index]=255;
        // calculate the new total
        for(int index2=index-m_width*local_size/2-local_size/2; index2<index+m_width*local_size/2-local_size/2; index2+=m_width) {
            total-=m_imageData[index2];
            total+=m_imageData[index2+local_size];
        }
    }
    return Image::createImage(result, m_width, m_height, true);
}

ImageWrapper *Image::autoThreshold() {
    int total=0;
    int count=0;
    for(int y=0; y<m_height; y++) {
        for(int x=0; x<m_width; x++) {
            total+=(*this)[y][x];
            count++;
        }
    }
    int threshold=total/count;
    Image *result=new Image(m_width, m_height);
    for(int y=0; y<m_height; y++) {
        for(int x=0; x<m_width; x++) {
            if((*this)[y][x]>threshold*0.8) {
                (*result)[y][x]=0;
            } else {
                (*result)[y][x]=255;
            }
        }
    }
    return [ImageWrapper imageWithCPPImage:result];
}

#define NOEDGE 255
#define POSSIBLE_EDGE 128
#define EDGE 0

void non_max_supp(int *mag, int *gradx, int *grady, int nrows, int ncols,
                  uint8_t *result)
{
    int rowcount, colcount,count;
    int *magrowptr,*magptr;
    int *gxrowptr,*gxptr;
    int *gyrowptr,*gyptr,z1,z2;
    int m00,gx=0,gy=0;
    float mag1,mag2,xperp = 0.0,yperp = 0.0;
    uint8_t *resultrowptr, *resultptr;
    
    
    /****************************************************************************
     * Zero the edges of the result image.
     ****************************************************************************/
    for(count=0,resultrowptr=result,resultptr=result+ncols*(nrows-1);
        count<ncols; resultptr++,resultrowptr++,count++){
        *resultrowptr = *resultptr = (unsigned char) 0;
    }
    
    for(count=0,resultptr=result,resultrowptr=result+ncols-1;
        count<nrows; count++,resultptr+=ncols,resultrowptr+=ncols){
        *resultptr = *resultrowptr = (unsigned char) 0;
    }
    
    /****************************************************************************
     * Suppress non-maximum points.
     ****************************************************************************/
    for(rowcount=1,magrowptr=mag+ncols+1,gxrowptr=gradx+ncols+1,
        gyrowptr=grady+ncols+1,resultrowptr=result+ncols+1;
        rowcount<nrows-2;
        rowcount++,magrowptr+=ncols,gyrowptr+=ncols,gxrowptr+=ncols,
        resultrowptr+=ncols){
        for(colcount=1,magptr=magrowptr,gxptr=gxrowptr,gyptr=gyrowptr,
            resultptr=resultrowptr;colcount<ncols-2;
            colcount++,magptr++,gxptr++,gyptr++,resultptr++){
            m00 = *magptr;
            if(m00 == 0){
                *resultptr = (unsigned char) NOEDGE;
            }
            else{
                xperp = -(gx = *gxptr)/((float)m00);
                yperp = (gy = *gyptr)/((float)m00);
            }
            
            if(gx >= 0){
                if(gy >= 0){
                    if (gx >= gy)
                    {
                        /* 111 */
                        /* Left point */
                        z1 = *(magptr - 1);
                        z2 = *(magptr - ncols - 1);
                        
                        mag1 = (m00 - z1)*xperp + (z2 - z1)*yperp;
                        
                        /* Right point */
                        z1 = *(magptr + 1);
                        z2 = *(magptr + ncols + 1);
                        
                        mag2 = (m00 - z1)*xperp + (z2 - z1)*yperp;
                    }
                    else
                    {
                        /* 110 */
                        /* Left point */
                        z1 = *(magptr - ncols);
                        z2 = *(magptr - ncols - 1);
                        
                        mag1 = (z1 - z2)*xperp + (z1 - m00)*yperp;
                        
                        /* Right point */
                        z1 = *(magptr + ncols);
                        z2 = *(magptr + ncols + 1);
                        
                        mag2 = (z1 - z2)*xperp + (z1 - m00)*yperp;
                    }
                }
                else
                {
                    if (gx >= -gy)
                    {
                        /* 101 */
                        /* Left point */
                        z1 = *(magptr - 1);
                        z2 = *(magptr + ncols - 1);
                        
                        mag1 = (m00 - z1)*xperp + (z1 - z2)*yperp;
                        
                        /* Right point */
                        z1 = *(magptr + 1);
                        z2 = *(magptr - ncols + 1);
                        
                        mag2 = (m00 - z1)*xperp + (z1 - z2)*yperp;
                    }
                    else
                    {
                        /* 100 */
                        /* Left point */
                        z1 = *(magptr + ncols);
                        z2 = *(magptr + ncols - 1);
                        
                        mag1 = (z1 - z2)*xperp + (m00 - z1)*yperp;
                        
                        /* Right point */
                        z1 = *(magptr - ncols);
                        z2 = *(magptr - ncols + 1);
                        
                        mag2 = (z1 - z2)*xperp  + (m00 - z1)*yperp;
                    }
                }
            }
            else
            {
                if ((gy = *gyptr) >= 0)
                {
                    if (-gx >= gy)
                    {
                        /* 011 */
                        /* Left point */
                        z1 = *(magptr + 1);
                        z2 = *(magptr - ncols + 1);
                        
                        mag1 = (z1 - m00)*xperp + (z2 - z1)*yperp;
                        
                        /* Right point */
                        z1 = *(magptr - 1);
                        z2 = *(magptr + ncols - 1);
                        
                        mag2 = (z1 - m00)*xperp + (z2 - z1)*yperp;
                    }
                    else
                    {
                        /* 010 */
                        /* Left point */
                        z1 = *(magptr - ncols);
                        z2 = *(magptr - ncols + 1);
                        
                        mag1 = (z2 - z1)*xperp + (z1 - m00)*yperp;
                        
                        /* Right point */
                        z1 = *(magptr + ncols);
                        z2 = *(magptr + ncols - 1);
                        
                        mag2 = (z2 - z1)*xperp + (z1 - m00)*yperp;
                    }
                }
                else
                {
                    if (-gx > -gy)
                    {
                        /* 001 */
                        /* Left point */
                        z1 = *(magptr + 1);
                        z2 = *(magptr + ncols + 1);
                        
                        mag1 = (z1 - m00)*xperp + (z1 - z2)*yperp;
                        
                        /* Right point */
                        z1 = *(magptr - 1);
                        z2 = *(magptr - ncols - 1);
                        
                        mag2 = (z1 - m00)*xperp + (z1 - z2)*yperp;
                    }
                    else
                    {
                        /* 000 */
                        /* Left point */
                        z1 = *(magptr + ncols);
                        z2 = *(magptr + ncols + 1);
                        
                        mag1 = (z2 - z1)*xperp + (m00 - z1)*yperp;
                        
                        /* Right point */
                        z1 = *(magptr - ncols);
                        z2 = *(magptr - ncols - 1);
                        
                        mag2 = (z2 - z1)*xperp + (m00 - z1)*yperp;
                    }
                }
            }
            
            /* Now determine if the current point is a maximum point */
            
            if ((mag1 > 0.0) || (mag2 > 0.0))
            {
                *resultptr = (unsigned char) NOEDGE;
            }
            else
            {
                if (mag2 == 0.0)
                    *resultptr = (unsigned char) NOEDGE;
                else
                    *resultptr = (unsigned char) POSSIBLE_EDGE;
            }
        }
    }
}

void follow_edges(uint8_t *edgemapptr, int *edgemagptr, short lowval,
                  int cols)
{
    int *tempmagptr;
    uint8_t *tempmapptr;
    int i;
    int x[8] = {1,1,0,-1,-1,-1,0,1},
    y[8] = {0,1,1,1,0,-1,-1,-1};
    
    for(i=0;i<8;i++){
        tempmapptr = edgemapptr - y[i]*cols + x[i];
        tempmagptr = edgemagptr - y[i]*cols + x[i];
        
        if((*tempmapptr == POSSIBLE_EDGE) && (*tempmagptr > lowval)){
            *tempmapptr = (unsigned char) EDGE;
            follow_edges(tempmapptr,tempmagptr, lowval, cols);
        }
    }
}

void apply_hysteresis(int *mag, uint8_t *nms, int rows, int cols,
                      float tlow, float thigh, uint8_t *edge)
{
    int r, c, pos, numedges, highcount, lowthreshold, highthreshold,hist[32768];
    int maximum_mag = 0;
    
    /****************************************************************************
     * Initialize the edge map to possible edges everywhere the non-maximal
     * suppression suggested there could be an edge except for the border. At
     * the border we say there can not be an edge because it makes the
     * follow_edges algorithm more efficient to not worry about tracking an
     * edge off the side of the image.
     ****************************************************************************/
    for(r=0,pos=0;r<rows;r++){
        for(c=0;c<cols;c++,pos++){
            if(nms[pos] == POSSIBLE_EDGE) edge[pos] = POSSIBLE_EDGE;
            else edge[pos] = NOEDGE;
        }
    }
    
    for(r=0,pos=0;r<rows;r++,pos+=cols){
        edge[pos] = NOEDGE;
        edge[pos+cols-1] = NOEDGE;
    }
    pos = (rows-1) * cols;
    for(c=0;c<cols;c++,pos++){
        edge[c] = NOEDGE;
        edge[pos] = NOEDGE;
    }
    
    /****************************************************************************
     * Compute the histogram of the magnitude image. Then use the histogram to
     * compute hysteresis thresholds.
     ****************************************************************************/
    for(r=0;r<32768;r++) hist[r] = 0;
    for(r=0,pos=0;r<rows;r++){
        for(c=0;c<cols;c++,pos++){
            if(edge[pos] == POSSIBLE_EDGE) hist[mag[pos]]++;
        }
    }
    
    /****************************************************************************
     * Compute the number of pixels that passed the nonmaximal suppression.
     ****************************************************************************/
    for(r=1,numedges=0;r<32768;r++){
        if(hist[r] != 0) maximum_mag = r;
        numedges += hist[r];
    }
    
    highcount = (int)(numedges * thigh + 0.5);
    
    /****************************************************************************
     * Compute the high threshold value as the (100 * thigh) percentage point
     * in the magnitude of the gradient histogram of all the pixels that passes
     * non-maximal suppression. Then calculate the low threshold as a fraction
     * of the computed high threshold value. John Canny said in his paper
     * "A Computational Approach to Edge Detection" that "The ratio of the
     * high to low threshold in the implementation is in the range two or three
     * to one." That means that in terms of this implementation, we should
     * choose tlow ~= 0.5 or 0.33333.
     ****************************************************************************/
    r = 1;
    numedges = hist[1];
    while((r<(maximum_mag-1)) && (numedges < highcount)){
        r++;
        numedges += hist[r];
    }
    highthreshold = r;
    lowthreshold = (int)(highthreshold * tlow + 0.5);
    /*
     if(VERBOSE){
     printf("The input low and high fractions of %f and %f computed to\n",
     tlow, thigh);
     printf("magnitude of the gradient threshold values of: %d %d\n",
     lowthreshold, highthreshold);
     }
     */
    /****************************************************************************
     * This loop looks for pixels above the highthreshold to locate edges and
     * then calls follow_edges to continue the edge.
     ****************************************************************************/
    for(r=0,pos=0;r<rows;r++){
        for(c=0;c<cols;c++,pos++){
            if((edge[pos] == POSSIBLE_EDGE) && (mag[pos] >= highthreshold)){
                edge[pos] = EDGE;
                follow_edges((edge+pos), (mag+pos), lowthreshold, cols);
            }
        }
    }
    
    /****************************************************************************
     * Set all the remaining possible edges to non-edges.
     ****************************************************************************/
    for(r=0,pos=0;r<rows;r++){
        for(c=0;c<cols;c++,pos++) if(edge[pos] != EDGE) edge[pos] = NOEDGE;
    }
}

/*
 tlow 0.20-0.50
 thigh 0.60-0.90
 */
ImageWrapper *Image::cannyEdgeExtract(float tlow, float thigh) {
    int gx[3][3]={
        { -1, 0, 1 },
        { -2, 0, 2 },
        { -1, 0, 1 }};
    int gy[3][3]={
        {  1,  2,  1 },
        {  0,  0,  0 },
        { -1, -2, -1 }};
    int resultWidth=m_width-3;
    int resultHeight=m_height-3;
    int *diffx=(int *) malloc(sizeof(int)*resultHeight*resultWidth);
    int *diffy=(int *) malloc(sizeof(int)*resultHeight*resultWidth);
    int *mag=(int *) malloc(sizeof(int)*resultHeight*resultWidth);
    memset(diffx, 0, sizeof(int)*resultHeight*resultWidth);
    memset(diffy, 0, sizeof(int)*resultHeight*resultWidth);
    memset(mag, 0, sizeof(int)*resultHeight*resultWidth);
    
    // compute the magnitute and the angles in the image
    for(int y=0; y<m_height-3; y++) {
        for(int x=0; x<m_width-3; x++) {
            int resultX=0;
            int resultY=0;
            for(int dy=0; dy<3; dy++) {
                for(int dx=0; dx<3; dx++) {
                    int pixel=(*this)[y+dy][x+dx];
                    resultX+=pixel*gx[dy][dx];
                    resultY+=pixel*gy[dy][dx];
                }
            }
            mag[y*resultWidth+x]=abs(resultX)+abs(resultY);
            diffx[y*resultWidth+x]=resultX;
            diffy[y*resultWidth+x]=resultY;
        }
    }
    uint8_t*nms=(uint8_t *) malloc(sizeof(uint8_t)*resultHeight*resultWidth);
    memset(nms, 0, sizeof(uint8_t)*resultHeight*resultWidth);
    non_max_supp(mag, diffx, diffy, resultHeight, resultWidth, nms);
    
    free(diffx);
    free(diffy);
    
    uint8_t *edge=(uint8_t *) malloc(sizeof(uint8_t)*resultHeight*resultWidth);
    memset(edge, 0, sizeof(uint8_t)*resultHeight*resultWidth);
    apply_hysteresis(mag, nms, resultHeight, resultWidth, tlow, thigh, edge);
    
    free(nms);
    free(mag);
    
    Image *result=new Image(edge, resultWidth, resultHeight, true);
    return [ImageWrapper imageWithCPPImage:result];
}

// rotate by 90, 180, 270, 360
ImageWrapper *Image::rotate(int angle) {
    Image* result = nullptr;
    switch(angle) {
        case 90:
        case 270:
            result=new Image(m_height, m_width);
            break;
        case 180:
            result=new Image(m_width, m_height);
            break;
    }
    for(int y=0; y< m_height; y++) {
        for(int x=0; x<m_width; x++) {
            switch(angle) {
                case 90:
                    (*result)[m_width-x-1][y]=(*this)[y][x];
                    break;
                case 180:
                    (*result)[m_height-y-1][x]=(*this)[y][x];
                    break;
                case 270:
                    (*result)[x][y]=(*this)[y][x];
                    break;
            }
        }
    }
    return [ImageWrapper imageWithCPPImage:result];
}

ImageWrapper *Image::gaussianBlur() {
    int blur[5][5]={
        { 1, 4, 7, 4, 1 },
        { 4,16,26,16, 4 },
        { 7,26,41,26, 7 },
        { 4,16,26,16, 4 },
        { 1, 4, 7, 4, 1 }};
    
    Image *result=new Image(m_width-5, m_height-5);
    for(int y=0; y<m_height-5; y++) {
        for(int x=0; x<m_width-5; x++) {
            int val=0;
            for(int dy=0; dy<5; dy++) {
                for(int dx=0; dx<5; dx++) {
                    int pixel=(*this)[y+dy][x+dx];
                    val+=pixel*blur[dy][dx];
                }
            }
            (*result)[y][x]=val/273;
        }
    }
    return [ImageWrapper imageWithCPPImage:result];
}


void Image::HistogramEqualisation() {
    std::vector<int> pdf(256);
    std::vector<int> cdf(256);
    // compute the pdf
    for(int i=0; i<m_height*m_width; i++) {
        pdf[m_imageData[i]]++;
    }
    // compute the cdf
    cdf[0]=pdf[0];
    for(int i=1; i<256; i++) {
        cdf[i]=cdf[i-1]+pdf[i];
    }
    // now map the pixels to the new values
    for(int i=0; i<m_height*m_width; i++) {
        m_imageData[i]=255*cdf[m_imageData[i]]/cdf[255];
    }
}

UIImage *Image::toUIImage() {
    // generate space for the result
    uint8_t *result=(uint8_t *) calloc(m_width*m_height*sizeof(uint32_t),1);
    // process the image back to rgb
    for(int i=0; i<m_height*m_width; i++) {
        result[i*4]=0;
        int val=m_imageData[i];
        result[i*4+1]=val;
        result[i*4+2]=val;
        result[i*4+3]=val;
    }
    // create a UIImage
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(result, m_width, m_height, 8, m_width*sizeof(uint32_t), colorSpace, kCGBitmapByteOrder32Little|kCGImageAlphaNoneSkipLast);
    CGImageRef image=CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    UIImage *resultUIImage=[UIImage imageWithCGImage:image];
    CGImageRelease(image);
    // make sure the data will be released by giving it to an autoreleased NSData
    [NSData dataWithBytesNoCopy:result length:m_width*m_height];
    return resultUIImage;
}

inline float Interpolate1(float a, float b, float c) {
    float mu=c-floor(c);
    return(a*(1-mu)+b*mu);
}

inline float Interpolate2(float a, float b, float c, float d, float x, float y)
{
    float ab = Interpolate1(a,b,x);
    float cd = Interpolate1(c,d,x);
    return Interpolate1(ab,cd,y);
}

ImageWrapper *Image::resize(int newX, int newY) {
    Image *result=new Image(newX, newY);
    for(float y=0; y<newY; y++) {
        for(float x=0; x<newX; x++) {
            float srcX0=x*(float)(m_width-1)/(float)newX;
            float srcY0=y*(float)(m_height-1)/(float)newY;
            float srcX1=(x+1)*(float)(m_width-1)/(float)newX;
            float srcY1=(y+1)*(float)(m_height-1)/(float)newY;
            float val=0,count=0;
            for(float srcY=srcY0; srcY<srcY1; srcY++) {
                for(float srcX=srcX0; srcX<srcX1; srcX++) {
                    val+=Interpolate2((*this)[(int)srcY][(int) srcX], (*this)[(int)srcY][(int) srcX+1],
                                      (*this)[(int)srcY+1][(int) srcX], (*this)[(int)srcY+1][(int) srcX+1],
                                      srcX, srcY);
                    count++;
                }
            }
            (*result)[(int) y][(int) x]=val/count;
        }
    }
    return [ImageWrapper imageWithCPPImage:result];
}

void Image::findLargestStructure(std::vector<ImagePoint> *maxPoints) {
    // process the image
    std::vector<ImagePoint> points;
    points.reserve(10000);
    for(int y=0; y<m_height; y++) {
        for(int x=0; x<m_width; x++) {
            // if we've found a point in the image then extract everything connected to it
            if((*this)[y][x]!=0) {
                extractConnectedRegion(x, y, &points);
                if(points.size()>maxPoints->size()) {
                    maxPoints->clear();
                    maxPoints->resize(points.size());
                    std::copy(points.begin(), points.end(), maxPoints->begin());
                }
                points.clear();
            }
        }
    }
}

int findHeightAtX(Image *img, int x) {
    // find the top most set pixel
    bool foundTop;
    int topY=0;
    for(;topY<img->getHeight(); topY++) {
        if((*img)[topY][x]==0) {
            foundTop=true;
            break;
        }
    }
    if(foundTop) {
        // find the bottom most set pixel
        int bottomY=img->getHeight()-1;
        for(;bottomY>0 && (*img)[bottomY][x]==0; bottomY--);
        return bottomY-topY;
    }
    return -1;
}

void Image::skeletonise() {
    bool changes=true;
    while(changes) {
        changes=false;
        for(int y=1; y<m_height-1; y++) {
            for(int x=1; x<m_width-1; x++) {
                if((*this)[y][x]!=0) {
                    bool val[8];
                    val[0]=(*this)[y-1][x-1]!=0;
                    val[1]=(*this)[y-1][x]!=0;
                    val[2]=(*this)[y-1][x+1]!=0;
                    val[3]=(*this)[y][x+1]!=0;
                    val[4]=(*this)[y+1][x+1]!=0;
                    val[5]=(*this)[y+1][x]!=0;
                    val[6]=(*this)[y+1][x-1]!=0;
                    val[7]=(*this)[y][x-1]!=0;
                    
                    bool remove=false;
                    for(int i=0; i<7 && !remove;i++) {
                        remove=(val[(0+i)%8] && val[(1+i)%8] && val[(7+i)%8] && val[(6+i)%8] && val[(5+i)%8] && !(val[(2+i)%8] || val[(3+i)%8] || val[(4+i)%8]))
                        || (val[(0+i)%8] && val[(1+i)%8] && val[(7+i)%8] && !(val[(3+i)%8] || val[(6+i)%8] || val[(5+i)%8] || val[(4+i)%8])) ||
                        !(val[(0+i)%8] || val[(1+i)%8] || val[(2+i)%8]  || val[(3+i)%8]  || val[(4+i)%8]  || val[(5+i)%8]  || val[(6+i)%8] || val[(7+i)%8]);
                    }
                    if(remove) {
                        (*this)[y][x]=0;
                        changes=true;
                    }
                }
            }
        }
    }
}