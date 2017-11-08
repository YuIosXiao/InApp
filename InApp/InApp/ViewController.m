//
//  ViewController.m
//  InApp
//
//  Created by MasterLing on 2017/11/8.
//  Copyright © 2017年 PandaProTool. All rights reserved.
//

#import "ViewController.h"
#import <StoreKit/StoreKit.h>

@interface ViewController ()<SKProductsRequestDelegate,SKPaymentTransactionObserver>

/**
 存放产品id
 */
@property (nonatomic, strong) NSArray * product_id_array;

/**
 购买按钮的tag
 */
@property (nonatomic, assign) NSInteger product_tag;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    可以根据实际情况，选择对应的流程来实现内购
//    内购的流程
//    1.APP请求苹果可销售的商品
//    2.代理方法获取可销售商品
//    3.展示商品
//    4.用户选择商品
//    5.根据用户选择的商品，给用户票据排队
//    6.监听交易队列变化
//    7.用户交钱，我们监听用户付款状态
//    8.付款成功，给用户对应的增值服务（付款成功需要进行对苹果返回的票单验证，有两种验证方式：1.本地验证；2.服务器验证；两种方式不同主要在于：本地可以只验证票单是否有效，服务器则需要验证票单具体数据，是否可靠。本地验证简单，验证后把验证的结果通过接口上传给服务器处理增值服务，但是容易被劫持，重复请求，不断地给用户增值服务。服务器相对复杂，但是相对安全。
//    9.交易结束
    //添加监听
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (NSArray *)product_id_array{
    if (!_product_id_array) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"productIDS" ofType:@"plist"];
        _product_id_array = [NSArray arrayWithContentsOfFile:path];
    }
    return _product_id_array;
}

- (IBAction)buyAction:(UIButton *)sender {
   
    if ([SKPaymentQueue canMakePayments]) {
        NSString *productid = self.product_id_array[sender.tag];
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:@[productid]]];
        request.delegate = self;
        [request start];
    }else{
        //做一些提示
    }
}
#pragma mark  代理方法
-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    if (response.invalidProductIdentifiers.count > 0) {
        NSLog(@"购买无效，请重新购买");
    }else{
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:response.products.firstObject];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}
#pragma mark  监听
- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased://购买成功
                [self paymentTransactionStatePurchased:transaction];
                break;
            case SKPaymentTransactionStateFailed://购买失败
                [self paymentTransactionStateFailed:transaction];
                break;
            case SKPaymentTransactionStateRestored://恢复购买
                [self paymentTransactionStateRestored:transaction];
                break;
            case SKPaymentTransactionStatePurchasing://正在处理
                break;
            default:
                break;
        }
    }
}
#pragma mark  支付成功
- (void) paymentTransactionStatePurchased:(SKPaymentTransaction *)transaction{
    //1.本地验证
    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed]
                                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    
    if (!requestData) { /* ... Handle error ... */ }
    
    
    NSURL *storeURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    
    // Make a connection to the iTunes Store on a background queue.
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   /* ... Handle error ... */
                                   NSLog(@"%@",connectionError);
                               } else {
                                   NSError *error;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                   if (!jsonResponse) { /* ... Handle error ...*/ }
                                   /* ... Send a response back to the device ... */
                                   //Parse the Response
                               }
                           }];
    //2.服务器验证
    //服务器验证需要验证苹果返回数据的具体内容，因为要判断上传给服务器的票单是否是已经增值过的票单，所以要上传交易的标识
    NSString *transactionIdentifier = transaction.transactionIdentifier;
    
    NSString * str=[[NSString alloc]initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding];
    NSString *environment=[self environmentForReceipt:str];
    if ([environment isEqualToString:@"environment=Sandbox"]) {
        environment = @"Sandbox";
    }else{
        environment = @"AppStore";
    }
    NSString *productIdentifier = transaction.payment.productIdentifier;
    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    if ([encodeStr length] > 0 && [productIdentifier length] > 0) {
        NSDictionary *parameters = @{@"environment":@"Sandbox",@"token":@"token",@"product_id":@"1",@"receipt":encodeStr,@"transaction_id":transactionIdentifier};
        
        [[NetworkHelpers sharedManager] handlePOSTWithUrlString:@"http://vps.xiongmao555.com/api/pay/in-app-purchase-verify" parameters:parameters showHuD:NO alertTitle:nil viewController:nil success:^(NSDictionary *json) {
            
            NSLog(@"%@",json);
        } fail:^{
            
        }];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

    
}

- (void) paymentTransactionStateFailed:(SKPaymentTransaction *)transaction{
    if (transaction.error.code != SKErrorPaymentCancelled) {
        NSLog(@"用户取消支付");
    }else{
        NSLog(@"支付失败");
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void) paymentTransactionStateRestored:(SKPaymentTransaction *)transaction{
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void) dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

//收据的环境判断；
-(NSString * )environmentForReceipt:(NSString * )str
{
    str= [str stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    str = [str stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    
    str=[str stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    str=[str stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    
    NSArray * arr=[str componentsSeparatedByString:@";"];
    
    //存储收据环境的变量
    NSString * environment=arr[2];
    return environment;
}

@end
