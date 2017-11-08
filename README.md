# InApp
苹果内购
    内购的流程
    1.APP请求苹果可销售的商品
    2.代理方法获取可销售商品
    3.展示商品
    4.用户选择商品
    5.根据用户选择的商品，给用户票据排队
    6.监听交易队列变化
    7.用户交钱，我们监听用户付款状态
    8.付款成功，给用户对应的增值服务（付款成功需要进行对苹果返回的票单验证，有两种验证方式：1.本地验证；2.服务器验证；两种方式不同主要在于：本地可以只验证票单是否有效，服务器则需要验证票单具体数据，是否可靠。本地验证简单，验证后把验证的结果通过接口上传给服务器处理增值服务，但是容易被劫持，重复请求，不断地给用户增值服务。服务器相对复杂，但是相对安全。
    9.交易结束
验证
    ñ内购购买成功后需要提交票单向服务器验证是否有效，然后再给用户增值服务。
    b本地验证
    receipt:
    ˚F服务器验证：
    productIdentifier:
    receipt: 
    transactionIdentifier:
    ÿ验证返回数据：
    ORIGINAL JSON: 
{
    "receipt":
    {
        "original_purchase_date_pst":"2015-06-22 20:56:34 America/Los_Angeles", //购买时间,太平洋标准时间
        "purchase_date_ms":"1435031794826", //购买时间毫秒
        "unique_identifier":"5bcc5503dbcc886d10d09bef079dc9ab08ac11bb",//唯一标识符
        "original_transaction_id":"1000000160390314", //原始交易ID
        "bvrs":"1.0",//iPhone程序的版本号
        "transaction_id":"1000000160390314", //交易的标识
        "quantity":"1", //购买商品的数量
        "unique_vendor_identifier":"AEEC55C0-FA41-426A-B9FC-324128342652", //开发商交易ID
        "item_id":"1008526677",//App Store用来标识程序的字符串
        "product_id":"cosmosbox.strikehero.gems60",//商品的标识 
        "purchase_date":"2015-06-23 03:56:34 Etc/GMT",//购买时间
        "original_purchase_date":"2015-06-23 03:56:34 Etc/GMT", //原始购买时间
        "purchase_date_pst":"2015-06-22 20:56:34 America/Los_Angeles",//太平洋标准时间
        "bid":"com.cosmosbox.StrikeHero",//iPhone程序的bundle标识
        "original_purchase_date_ms":"1435031794826"//毫秒
    },
    "status":0 //状态码,0为成功
}
苹果状态码
Status	描述
21000	App Store不能读取你提供的JSON对象
21002	receipt-data域的数据有问题
21003	receipt无法通过验证
21004	提供的shared secret不匹配你账号中的shared secret
21005	receipt服务器当前不可用
21006	receipt合法，但是订阅已过期。服务器接收到这个状态码时，receipt数据仍然会解码并一起发送
21007	receipt是Sandbox receipt，但却发送至生产系统的验证服务
21008	receipt是生产receipt，但却发送至Sandbox环境的验证服务
