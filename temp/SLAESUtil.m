//
//  SLAESUtil.m
//  TransferedLogic
//
//  Created by 徐涛 on 5/6/15.
//  Copyright (c) 2015 liao. All rights reserved.
//

#import "SLAESUtil.h"
#include <openssl/aes.h>

@implementation SLAESUtil

+ (NSData *)doCipher:(NSData *)dataIn
                 key:(NSData *)symmetricKey
             context:(CCOperation)encryptOrDecrypt
               error:(NSError **)error
{
    CCCryptorStatus ccStatus   = kCCSuccess;
    size_t          cryptBytes = 0;
    NSMutableData  *dataOut    = [NSMutableData dataWithLength:dataIn.length + kCCBlockSizeAES128];
    
    ccStatus = CCCrypt(encryptOrDecrypt,
                       kCCAlgorithmAES128,
                       kCCOptionECBMode|kCCOptionPKCS7Padding,
                       symmetricKey.bytes,
                       kCCKeySizeAES256,
                       NULL,
                       dataIn.bytes,
                       dataIn.length,
                       dataOut.mutableBytes,
                       dataOut.length,
                       &cryptBytes);
    
    if (ccStatus == kCCSuccess) {
        dataOut.length = cryptBytes;
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"kEncryptionError"
                                         code:ccStatus
                                     userInfo:nil];
        }
        dataOut = nil;
    }
    
    return dataOut;
}

@end
