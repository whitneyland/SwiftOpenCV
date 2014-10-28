//
//  ImageWrapper.h
//  OCR-Example
//
//  Based on: http://stackoverflow.com/questions/11624694/what-is-the-ideal-image-for-tesseract-library

#import <UIKit/UIImage.h>
#include <vector>

class Image;
// objective C wrapper for our image class
@interface ImageWrapper : NSObject {
    Image *image;
    bool ownsImage;
}

@property(assign, nonatomic) Image *image;
@property(assign, nonatomic) bool ownsImage;
+ (ImageWrapper *) imageWithCPPImage:(Image *) theImage;

@end

class ImagePoint {
public:
    short x,y;
    inline ImagePoint(short xpos, short ypos) {
        x=xpos;
        y=ypos;
    }
    inline ImagePoint(int xpos, int ypos) {
        x=xpos;
        y=ypos;
    }
    inline ImagePoint(const ImagePoint &other) {
        x=other.x;
        y=other.y;
    }
    inline ImagePoint() {
        x=0; y=0;
    }
};

class Image {
private:
    uint8_t *m_imageData;
    uint8_t **m_yptrs;
    int m_width;
    int m_height;
    bool m_ownsData;
    Image(ImageWrapper *other, int x1, int y1, int x2, int y2);
    Image(int width, int height);
    Image(uint8_t *imageData, int width, int height, bool ownsData=false);
    Image(UIImage *srcImage, int width, int height, CGInterpolationQuality interpolation, bool imageIsRotatedBy90degrees=false);
    void initYptrs();
public:
    // copy a section of another image
    static ImageWrapper *createImage(ImageWrapper *other, int x1, int y1, int x2, int y2);
    // create an empty image of the required width and height
    static ImageWrapper *createImage(int width, int height);
    // create an image from data
    static ImageWrapper *createImage(uint8_t *imageData, int width, int height, bool ownsData=false);
    // take a source UIImage and convert it to greyscale
    static ImageWrapper *createImage(UIImage *srcImage, int width, int height, bool imageIsRotatedBy90degrees=false);
    // edge detection
    ImageWrapper *cannyEdgeExtract(float tlow, float thigh);
    // local thresholding
    ImageWrapper* autoLocalThreshold();
    // threshold using integral
    ImageWrapper *autoIntegratingThreshold();
    // threshold an image automatically
    ImageWrapper *autoThreshold();
    // gaussian smooth the image
    ImageWrapper *gaussianBlur();
    // get the percent set pixels
    int getPercentSet();
    // exrtact a connected area from the image
    void extractConnectedRegion(int x, int y, std::vector<ImagePoint> *points);
    // find the largest connected region in the image
    void findLargestStructure(std::vector<ImagePoint> *maxPoints);
    // normalise an image
    void normalise();
    // rotate by 90, 180, 270, 360
    ImageWrapper *rotate(int angle);
    // shrink to a new size
    ImageWrapper *resize(int newX, int newY);
    ImageWrapper *shrinkBy2();
    // histogram equalisation
    void HistogramEqualisation();
    // skeltonize
    void skeletonise();
    // convert back to a UIImage for display
    UIImage *toUIImage();
    ~Image() {
        if(m_ownsData)
            free(m_imageData);
        delete m_yptrs;
    }
    inline uint8_t* operator[](const int rowIndex) {
        return m_yptrs[rowIndex];
    }
    inline int getWidth() {
        return m_width;
    }
    inline int getHeight() {
        return m_height;
    }
};

inline bool sortByX1(const ImagePoint &p1, const ImagePoint &p2) {
    if(p1.x==p2.x) return p1.y<p2.y;
    return p1.x<p2.x;
}

inline bool sortByY1(const ImagePoint &p1, const ImagePoint &p2) {
    if(p1.y==p2.y) return p1.x<p2.x;
    return p1.y<p2.y;
}