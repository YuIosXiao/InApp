#import "sddsdViewController.h"
#import <StoreKit/StoreKit.h>
#import "MaskView.h"

@interface sddsdViewController()<SKPaymentTransactionObserver,SKProductsRequestDelegate>
//productId是在开发者平台填写的产品id,排队加速
@property(nonatomic,copy)NSString *productId;

@property(nonatomic,strong)MaskView *maskView;

@property(nonatomic,assign)BOOL isAccelerate;

@property(nonatomic,strong)NSString *filePath;

@end

@implementation sddsdViewController

- (instancetype)initWithAccelerate:(BOOL)isAccelerate;

{
    self = [super init];
    if (self) {
        
        self.isAccelerate = isAccelerate;
        
        
    }
    return self;
}

- (void)setIsAccelerate:(BOOL)isAccelerate
{
    _isAccelerate = isAccelerate;
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    //槽位的路径
    NSString *receiptPath = [docPath stringByAppendingPathComponent:@"slot_receitp.plist"];
    
    if (_isAccelerate == YES) {
        
        receiptPath = [docPath stringByAppendingPathComponent:@"accelerate_receitp.plist"];
    }
    self.filePath = receiptPath;
}

- (void)pay
{
    
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:self.filePath];
    
    if (dic  != nil) {
        
        DLog(@"沙盒中拿");
        
        NSString *receiptEncodeStr = dic[@"receiptEncodeStr"];
        //去服务器验证
        //配置服务器需要的参数
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"xxx"] = xxx;
        //params[@"xxx"] = @(1x);
        params[@"xxx"] = xxxx;
        params[@"xxx"] = @(false);
        [self verifyPurchaseWithDic:params];
        
        return;
    }
    
    //添加一个交易队列观察者
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    //判断是否允许程序内购买
    if ([SKPaymentQueue canMakePayments]) {
        
        //获取商品列表
        WS(weakSelf)
        [SWAYNetWorking get:IapProductInfoUrl parameters:nil success:^(id responseObject) {
            
            if ([responseObject[@"code"] integerValue] == 100) {
                
                NSDictionary *dic = [responseObject[@"data"] objectAtIndex:0];
                if (self.isAccelerate == NO) {
                    dic = [responseObject[@"data"] objectAtIndex:1];
                }
                NSInteger p_id = [dic[@"productId"] integerValue];
                weakSelf.productId =  [NSString stringWithFormat:@"%ld",p_id];
                //去苹果服务器请求产品信息
                [weakSelf requestProductData:weakSelf.productId];
            }
            
        } failure:^(NSError *error) {
            
        }];
        
        
    }else{
        
        [SVProgressHUD showImage:nil status:@"用户禁止应用内购买,请到设置->通用->访问限制里打开App内购买项目"];
        
    }
    
}


// 去苹果服务器请求产品信息
- (void)requestProductData:(NSString *)productId {
    
    self.maskView = [[MaskView alloc]init];
    [KWindow addSubview:self.maskView];
    [self.maskView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.top.mas_equalTo(0);
    }];
    
    
    
    NSArray *productArr = [[NSArray alloc]initWithObjects:productId, nil];
    
    NSSet *productSet = [NSSet setWithArray:productArr];
    
    SKProductsRequest *request = [[SKProductsRequest alloc]initWithProductIdentifiers:productSet];
    request.delegate = self;
    [request start];
    
}

// SKProductsRequestDelegate 收到产品返回信息
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
    
    NSArray *productArr = response.products;
    
    if ([productArr count] == 0) {
        
        DLog(@"没有该商品");
        [self.maskView removeFromSuperview];
        return;
    }
    
    DLog(@"productId = %@",response.invalidProductIdentifiers);
    DLog(@"产品付费数量 = %zd",productArr.count);
    
    SKProduct *p = nil;
    
    for (SKProduct *pro in productArr) {
        DLog(@"description:%@",[pro description]);
        DLog(@"localizedTitle:%@",[pro localizedTitle]);
        DLog(@"localizedDescription:%@",[pro localizedDescription]);
        DLog(@"price:%@",[pro price]);
        DLog(@"productIdentifier:%@",[pro productIdentifier]);
        if ([pro.productIdentifier isEqualToString:self.productId]) {
            p = pro;
        }
    }
    
    SKPayment *payment = [SKPayment paymentWithProduct:p];
    
    //发送内购请求
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"完成");
    [self.maskView removeFromSuperview];
}



- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSString *errMessage = [error.userInfo objectForKey:@"NSLocalizedDescription"];
    [SVProgressHUD showErrorWithStatus:errMessage];
    [self.maskView removeFromSuperview];
    
}


// SKPaymentTransactionObserver监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    
    for (SKPaymentTransaction *tran in transactions) {
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased: //交易完成
                // 发送到服务器验证凭证
                [self completeTransaction:tran];
                [[SKPaymentQueue defaultQueue]finishTransaction:tran];
                break;
            case SKPaymentTransactionStatePurchasing: //商品添加进列表
                
                break;
            case SKPaymentTransactionStateRestored: //购买过
                // 发送到苹果服务器验证凭证
                [[SKPaymentQueue defaultQueue]finishTransaction:tran];
                break;
            case SKPaymentTransactionStateFailed: //交易失败
                
                [[SKPaymentQueue defaultQueue]finishTransaction:tran];
                [SVProgressHUD showErrorWithStatus:@"购买失败"];
                break;
                
            default:
                break;
        }
    }
}

- (void) completeTransaction: (SKPaymentTransaction *)transaction
{
    //商品id
    NSString *produckID = transaction.payment.productIdentifier;
    //订单号
    NSString *transactionIdentifier = transaction.transactionIdentifier;
    
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 从沙盒中获取到购买凭据
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    NSString *receiptEncodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    
    //存储收据
    NSMutableDictionary *receiptDic = [NSMutableDictionary dictionary];
    [receiptDic setObject:produckID forKey:@"produckID"];
    [receiptDic setObject:transactionIdentifier forKey:@"transactionIdentifier"];
    [receiptDic setObject:receiptEncodeStr forKey:@"receiptEncodeStr"];
    
    
    [receiptDic writeToFile:self.filePath atomically:YES];
    //配置服务器需要的参数
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"receipt"] = receiptEncodeStr;
    params[@"chooseEnv"] = @(false);
    [self verifyPurchaseWithDic:params];
    
}

#pragma mark-  服务器端做验证
- (void)verifyPurchaseWithDic:(NSDictionary *)dic
{
    [NetWorking post:IapCertificateUrl parameters:dic success:^(id responseObject) {
        
        if ([responseObject[@"code"] integerValue] == 100) {
            
            //刷新首页
            [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadHomeNotification" object:nil];
            
            [SVProgressHUD showImage:nil status:responseObject[@"message"]];
            
            [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
            
            
        }else{
            
            [SVProgressHUD showImage:nil status:responseObject[@"message"]];
            
            
        }
        
    } failure:^(NSError *error) {
        
    }];
}


//沙盒测试环境验证
#define SANDBOX @"https://sandbox.itunes.apple.com/verifyReceipt"
//正式环境验证
#define AppStore @"https://buy.itunes.apple.com/verifyReceipt"
// 验证购买
- (void)verifyPurchaseWithPaymentTrasaction {
    
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 从沙盒中获取到购买凭据
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    
    
    // 发送网络POST请求，对购买凭据进行验证
    //测试验证地址:https://sandbox.itunes.apple.com/verifyReceipt
    //正式验证地址:https://buy.itunes.apple.com/verifyReceipt
    NSURL *url = [NSURL URLWithString:SANDBOX];
    NSMutableURLRequest *urlRequest =
    [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f];
    urlRequest.HTTPMethod = @"POST";
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    NSString *payload = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    urlRequest.HTTPBody = payloadData;
    // 提交验证请求，并获得官方的验证JSON结果 iOS9后更改了另外的一个方法
    NSData *result = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:nil error:nil];
    // 官方验证结果为空
    if (result == nil) {
        NSLog(@"验证失败");
        return;
    }
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:result options:NSJSONReadingAllowFragments error:nil];
    if (dict != nil) {
        // 比对字典中以下信息基本上可以保证数据安全
        // bundle_id , application_version , product_id , transaction_id
        //        NSLog(@"验证成功！购买的商品是：%@", @"_productName");
        
        NSLog(@"验证成功%@",dict);
    }
    
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}




@end
