//
//  ViewController.m
//  EdgeDetection
//
//  Created by Rodrigo Ramele on 10/17/16.
//  Copyright © 2016 Baufest. All rights reserved.
//

#import <SystemConfiguration/CaptiveNetwork.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetRepresentation.h>
#import <ImageIO/CGImageSource.h>
#import <ImageIO/CGImageProperties.h>
#import "ViewController.h"
#import <opencv2/opencv.hpp>

#import <mach/mach_time.h>


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *previewCamera;
@property (weak, nonatomic) IBOutlet UIImageView *postviewImage;

@end

@implementation ViewController

AVCaptureVideoPreviewLayer *_previewLayer;
AVCaptureSession *_captureSession;
AVCaptureStillImageOutput *stillImageOutput;
dispatch_queue_t _videoDataOutputQueue;



- (void)viewDidLoad {
    [super viewDidLoad];

    
    
    // ----- La primera parte crea los componentes para acceder a la cámara y los asocia a una imagen para provocar visualizaciones.
    // Creamos una Cola sincrónica para la recepción de los mensajes con los frames.
    _videoDataOutputQueue = dispatch_queue_create("com.test.app", NULL); //create a serial queue can either be null or DISPATCH_QUEUE_SERIAL
    
    // Inicializamos el objeto para hacer la captura.
    _captureSession = [[AVCaptureSession alloc] init];
    
    // Creamos un device, un device input asociado.
    AVCaptureDevice * videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(videoDevice == nil)
        assert(0);
    
    //...y agregamos ese input a la sesión de captura.
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice
                                                                        error:&error];
    if(error)
        assert(0);
    
    [_captureSession addInput:input];
    
    //Agregamos un Layer de Preview que va a estar asociado a un cuadro de imagen.
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    [_previewLayer setFrame:CGRectMake(0, 0,
                                       self.previewCamera.frame.size.width,
                                       self.previewCamera.frame.size.height)];
    
    //Finalmente agregamos el layer a la imágen.
    [self.previewCamera.layer addSublayer:_previewLayer];
    
    
    // ----- Esta segunda parte, permite sacar una foto.
    
    //stillImageOutput = [[AVCaptureStillImageOutput alloc]init];
    
    //[_captureSession addOutput:stillImageOutput];
    
    
    // ----- La tercera parte, arma la captura de los frames.
    
    AVCaptureVideoDataOutput *videoDataOutput = [AVCaptureVideoDataOutput new];
    
    NSDictionary *newSettings =
    @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    
    videoDataOutput.videoSettings = newSettings;
    
    // Esto es importante, ya que fuerza descartar aquellos frames que no se pueden procesar por falta de tiempo en el ciclo de procesamiento.
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    // Usa la cola sincrónica para enviar los frames.
    _videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:_videoDataOutputQueue];
    
    AVCaptureSession *captureSession = _captureSession;
    
    if ( [captureSession canAddOutput:videoDataOutput] )
        [captureSession addOutput:videoDataOutput];
    
    
    //-- Finalmente dispara la captura de la cámara.
    //[_captureSession startRunning];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_captureSession startRunning];
    
    NSArray *array = [[_captureSession.outputs objectAtIndex:0] connections];
    for (AVCaptureConnection *connection in array)
    {
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// Método del delegado para capturar frame by frame.
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection;
{
    // Create a UIImage from the sample buffer data
    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    
    cv::Mat inputMat = [self cvMatFromUIImage:image];
    
    NSLog(@"Cols %d, Rows %d",inputMat.cols, inputMat.rows);
    
    //[self processImage:inputMat];
    
    cv::Mat greyMat;
    cv::cvtColor(inputMat, greyMat, CV_BGR2GRAY);
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
     {
         self.postviewImage.image = [self UIImageFromCVMat:greyMat];
     }];
    
    
    //self.imageView.image = image;
}



// Obturador !
-(IBAction) captureNow
{
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in stillImageOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    
    NSLog(@"about to request a capture from: %@", stillImageOutput);
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         /**
          CFDictionaryRef exifAttachments = CMGetAttachment( imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
          if (exifAttachments)
          {
          // Do something with the attachments.
          NSLog(@"attachements: %@", exifAttachments);
          }
          else
          NSLog(@"no attachments");
          **/
         
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
         UIImage *image = [[UIImage alloc] initWithData:imageData];
         
         cv::Mat inputMat = [self cvMatFromUIImage:image];
         
         NSLog(@"Cols %d, Rows %d",inputMat.cols, inputMat.rows);
         
         
         //cv::Mat greyMat;
         //cv::cvtColor(inputMat, greyMat, CV_BGR2GRAY);
         
         //self.imageView.image = [self UIImageFromCVMat:inputMat];
         
         
         
         self.previewCamera.image = image;
     }];
}


// Utilities
// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    NSLog(@"imageFromSampleBuffer: called");
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}


- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

- (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}



-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    //cv::transpose(cvMat, cvMatDst);
    //flip(cvMatDst, cvMatDst,1);

    
    Canny( cvMat, cvMat, 50, 150, 3);
    
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    NSLog(@"Cols %d and rows %d:", cvMat.cols, cvMat.rows);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}


@end
