# IOS RSA加密遇到的坑


------

最近在项目涉及到一点RSA算法问题，RSA是非对称秘钥加密，IOS在Security中支持大多数加密算法,AES, DES, RSA等。

我在用Security.framework时候遇到一个问题，用pem生成Public Key时候出错

```objc
 + (SecKeyRef)addPublicKey:(NSString *)key {
	NSRange spos = [key rangeOfString:@"-----BEGIN PUBLIC KEY-----"];
	NSRange epos = [key rangeOfString:@"-----END PUBLIC KEY-----"];
	if(spos.location != NSNotFound && epos.location != NSNotFound){
		NSUInteger s = spos.location + spos.length;
		NSUInteger e = epos.location;
		NSRange range = NSMakeRange(s, e-s);
		key = [key substringWithRange:range];
	}
	//注意，中间部分才是base64加密的public key，而且需要干掉换行空格
	key = [key stringByReplacingOccurrencesOfString:@"\r" withString:@""];
	key = [key stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	key = [key stringByReplacingOccurrencesOfString:@"\t" withString:@""];
	key = [key stringByReplacingOccurrencesOfString:@" "  withString:@""];
	//base64 解密key
	NSData *data = base64_decode(key);
	data = [RSA stripPublicKeyHeader:data];
	if(!data){
		return nil;
	}
	//a tag to read/write keychain storage
	NSString *tag = @"SL_PubKey";
	NSData *d_tag = [NSData dataWithBytes:[tag UTF8String] length:[tag length]];
	
	// 先要删掉keychain中以前存的
	NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
	[publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
	[publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	[publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
	SecItemDelete((__bridge CFDictionaryRef)publicKey);
	
	// 将public key加入keychain中
	[publicKey setObject:data forKey:(__bridge id)kSecValueData];
	[publicKey setObject:(__bridge id) kSecAttrKeyClassPublic forKey:(__bridge id)
	 kSecAttrKeyClass];
	[publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)
	 kSecReturnPersistentRef];
	
	CFTypeRef persistKey = nil;
	OSStatus status = SecItemAdd((__bridge CFDictionaryRef)publicKey, &persistKey);
	if (persistKey != nil){
		CFRelease(persistKey);
	}
	if ((status != noErr) && (status != errSecDuplicateItem)) {
		return nil;
	}

	[publicKey removeObjectForKey:(__bridge id)kSecValueData];
	[publicKey removeObjectForKey:(__bridge id)kSecReturnPersistentRef];
	[publicKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
	[publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
	
	// 取SecKeyRef
	SecKeyRef keyRef = nil;
	status = SecItemCopyMatching((__bridge CFDictionaryRef)publicKey, (CFTypeRef *)&keyRef);
	if(status != noErr){
		return nil;
	}
	return keyRef;
}
```
上面这段代码是根据pem格式文件内容字符串（因为是base64过的）生成public key，我用iPhone6，iOS9.1连接Xcode Debug测试时候发现，某些情况调用SecItemAdd往keychain中添加秘钥时候status code 返回-34018，我google了一番，这是IOS的bug，具体请参考

> https://forums.developer.apple.com/thread/4743#14441

这个bug只会在device连接xcode调试时候出现，断开调试用device直接跑的时候不会出现添加失败情况。还没有找到解决方案😭。

为了解决这个问题，我打算放弃使用iOS自带的RSA，改用openssl的RSA实现。代码如下：
```c

NSString *rsa_public_encrypt(NSData *data, void *public_key_val) {
    RSA *rsa_publicKey = NULL;
    int rsa_public_len;
    BIO *bio = NULL;
    
    bio = BIO_new_mem_buf(public_key_val, -1);
    if (bio == NULL){
        printf("Pub Key Read Failure\n");
    }
    rsa_publicKey = PEM_read_bio_RSA_PUBKEY(bio, NULL, NULL, NULL);
    if (rsa_publicKey == NULL) {
        printf("RSA Generate failure\n");
    };
    
    rsa_public_len = RSA_size(rsa_publicKey);
    printf("RSA public length: %d\n", rsa_public_len);
    
    // 11 bytes is overhead required for encryption
    int chunk_length = rsa_public_len - 11;
    // plain text length
    unsigned long dataLength = data.length;
    // calculate the number of chunks
    int num_of_chunks = (int)(dataLength / chunk_length) + 1;
    
    int total_cipher_length = 0;
    
    // the output size is (total number of chunks) x (the key length)
    int encrypted_size = (num_of_chunks * rsa_public_len);
    unsigned char *cipher_data = malloc(encrypted_size + 1);
    
    const void *plainBytes = data.bytes;
    char *err = NULL;
    for (int i = 0; i < dataLength; i += chunk_length) {
        
        // get the remaining character count from the plain text
        int remaining_char_count = (int)dataLength - i;
        
        // this len is the number of characters to encrypt, thus take the minimum between the chunk count & the remaining characters
        // this must less than rsa_public_len - 11
        int len = RSMIN(remaining_char_count, chunk_length);
        unsigned char *plain_chunk = malloc(len + 1);
        // take out chunk of plain text
        memcpy(&plain_chunk[0], &plainBytes[i], len);
        unsigned char *result_chunk = malloc(rsa_public_len + 1);
        int result_length = RSA_public_encrypt(len, plain_chunk, result_chunk, rsa_publicKey, RSA_PKCS1_PADDING);
        free(plain_chunk);
        if (result_length == -1) {
            ERR_load_CRYPTO_strings();
            fprintf(stderr, "Error %s\n", ERR_error_string(ERR_get_error(), err));
            fprintf(stderr, "Error %s\n", err);
        }
        memcpy(&cipher_data[total_cipher_length], &result_chunk[0], result_length);
        
        total_cipher_length += result_length;
        
        free(result_chunk);
    }
    RSA_free(rsa_publicKey);
    size_t total_len = 0;
    unsigned char *encrypted = rsa_base64_encode(cipher_data, encrypted_size, &total_len);
    free(cipher_data);
    
    return [[NSString alloc] initWithBytes:encrypted length:total_len encoding:NSUTF8StringEncoding];
}

NSData *rsa_public_decrypt(NSData *data, void *public_key_val) {
    RSA *rsa_publicKey = NULL;
    int rsa_public_len;
    BIO *bio = NULL;
    
    bio = BIO_new_mem_buf(public_key_val, -1);
    if (bio == NULL){
        printf("Public Key Read Failure\n");
    }
    rsa_publicKey = PEM_read_bio_RSA_PUBKEY(bio, NULL, NULL, NULL);
    if (rsa_publicKey == NULL) {
        printf("RSA Generate failure\n");
    }
    
    rsa_public_len = RSA_size(rsa_publicKey);
    printf("RSA public length: %d\n", rsa_public_len);
    
    size_t crypt_len = data.length;
    
    const char *crypt = data.bytes;
    
    NSMutableData *result = [NSMutableData data];
    char *err = NULL;
    for (int i = 0; i < crypt_len; i += rsa_public_len) {
        unsigned char *crypt_chunk = malloc(rsa_public_len);
        memcpy(&crypt_chunk[0], &crypt[i], rsa_public_len);
        unsigned char *result_chunk = malloc(crypt_len + 1);
        int result_length = RSA_public_decrypt(rsa_public_len, crypt_chunk, result_chunk, rsa_publicKey, RSA_PKCS1_PADDING);
        free(crypt_chunk);
        [result appendBytes:result_chunk length:result_length];
        free(result_chunk);
        if (result_length == -1) {
            ERR_load_CRYPTO_strings();
            fprintf(stderr, "Error %s\n", ERR_error_string(ERR_get_error(), err));
            fprintf(stderr, "Error %s\n", err);
        }
    }
    RSA_free(rsa_publicKey);
    return result;
}
```
这里有几个问题要注意：
 

> 1、公钥字符串每一行后面要加一个\n
> 2、加密后的数据长度
> 3、解密后的数据长度

 

