/**
 * Copyright (C) 2014 Virgil Security Inc.
 *
 * Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     (1) Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *
 *     (2) Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in
 *     the documentation and/or other materials provided with the
 *     distribution.
 *
 *     (3) Neither the name of the copyright holder nor the names of its
 *     contributors may be used to endorse or promote products derived from
 *     this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <virgil/service/VirgilCipher.h>
using virgil::service::VirgilCipher;
using virgil::service::VirgilCipherDatagram;

#include <virgil/VirgilByteArray.h>
using virgil::VirgilByteArray;

#include <virgil/crypto/VirgilSymmetricCipher.h>
using virgil::crypto::VirgilSymmetricCipher;

#include <virgil/crypto/VirgilKDF.h>
using virgil::crypto::VirgilKDF;

#include <virgil/crypto/VirgilAsymmetricCipher.h>
using virgil::crypto::VirgilAsymmetricCipher;

VirgilCipher::~VirgilCipher() throw() {
}

VirgilCipherDatagram VirgilCipher::encrypt(const VirgilByteArray& data, const VirgilByteArray& publicKey) {
    VirgilSymmetricCipher symmetricCipher = VirgilSymmetricCipher::aes256();

    VirgilByteArray encryptionKey = configureEncryption(symmetricCipher);

    VirgilByteArray firstChunk = symmetricCipher.update(data);
    VirgilByteArray secondChunk = symmetricCipher.finish();

    VirgilByteArray encryptedData;
    encryptedData.insert(encryptedData.end(), firstChunk.begin(), firstChunk.end());
    encryptedData.insert(encryptedData.end(), secondChunk.begin(), secondChunk.end());

    VirgilAsymmetricCipher asymmetricCipher = VirgilAsymmetricCipher::none();
    asymmetricCipher.setPublicKey(publicKey);

    return  VirgilCipherDatagram(asymmetricCipher.encrypt(encryptionKey), encryptedData);
}

VirgilByteArray VirgilCipher::decrypt(const VirgilByteArray encryptedData, const VirgilByteArray& encryptionKey,
        const VirgilByteArray& privateKey, const VirgilByteArray& privateKeyPassword) {

    VirgilAsymmetricCipher asymmetricCipher = VirgilAsymmetricCipher::none();
    asymmetricCipher.setPrivateKey(privateKey, privateKeyPassword);

    VirgilByteArray decryptionKey = asymmetricCipher.decrypt(encryptionKey);

    VirgilSymmetricCipher symmetricCipher = VirgilSymmetricCipher::aes256();
    configureDecryption(symmetricCipher, decryptionKey);

    VirgilByteArray firstChunk = symmetricCipher.update(encryptedData);
    VirgilByteArray secondChunk = symmetricCipher.finish();

    VirgilByteArray decryptedData;
    decryptedData.insert(decryptedData.end(), firstChunk.begin(), firstChunk.end());
    decryptedData.insert(decryptedData.end(), secondChunk.begin(), secondChunk.end());

    return decryptedData;
}

VirgilByteArray VirgilCipher::encryptWithPassword(const VirgilByteArray& data, const VirgilByteArray& pwd) {
    VirgilSymmetricCipher symmetricCipher = VirgilSymmetricCipher::aes256();

    VirgilByteArray encryptionKey = VirgilKDF::kdf1(pwd, symmetricCipher.keyLength());
    configureEncryption(symmetricCipher, encryptionKey);

    VirgilByteArray firstChunk = symmetricCipher.update(data);
    VirgilByteArray secondChunk = symmetricCipher.finish();

    VirgilByteArray encryptedData;
    encryptedData.insert(encryptedData.end(), firstChunk.begin(), firstChunk.end());
    encryptedData.insert(encryptedData.end(), secondChunk.begin(), secondChunk.end());

    return encryptedData;
}

VirgilByteArray VirgilCipher::decryptWithPassword(const VirgilByteArray& data, const VirgilByteArray& pwd) {
    VirgilSymmetricCipher symmetricCipher = VirgilSymmetricCipher::aes256();
    VirgilByteArray decryptionKey = VirgilKDF::kdf1(pwd, symmetricCipher.keyLength());
    configureDecryption(symmetricCipher, decryptionKey);

    VirgilByteArray firstChunk = symmetricCipher.update(data);
    VirgilByteArray secondChunk = symmetricCipher.finish();

    VirgilByteArray decryptedData;
    decryptedData.insert(decryptedData.end(), firstChunk.begin(), firstChunk.end());
    decryptedData.insert(decryptedData.end(), secondChunk.begin(), secondChunk.end());

    return decryptedData;
}
