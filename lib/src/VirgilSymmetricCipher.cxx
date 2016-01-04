/**
 * Copyright (C) 2015 Virgil Security Inc.
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

#include <virgil/crypto/foundation/VirgilSymmetricCipher.h>

#include <polarssl/cipher.h>
#include <polarssl/oid.h>

#include <virgil/crypto/VirgilByteArray.h>
#include <virgil/crypto/VirgilCryptoException.h>
#include <virgil/crypto/foundation/PolarsslException.h>
#include <virgil/crypto/foundation/asn1/VirgilAsn1Compatible.h>
#include <virgil/crypto/foundation/asn1/VirgilAsn1Reader.h>
#include <virgil/crypto/foundation/asn1/VirgilAsn1Writer.h>
#include <virgil/crypto/foundation/priv/VirgilTagFilter.h>

using virgil::crypto::VirgilByteArray;
using virgil::crypto::VirgilCryptoException;

using virgil::crypto::foundation::PolarsslException;
using virgil::crypto::foundation::VirgilSymmetricCipher;
using virgil::crypto::foundation::VirgilSymmetricCipherImpl;
using virgil::crypto::foundation::asn1::VirgilAsn1Compatible;
using virgil::crypto::foundation::asn1::VirgilAsn1Reader;
using virgil::crypto::foundation::asn1::VirgilAsn1Writer;
using virgil::crypto::foundation::priv::VirgilTagFilter;

namespace virgil { namespace crypto { namespace foundation {

class VirgilSymmetricCipherImpl {
public:
    VirgilSymmetricCipherImpl(cipher_type_t cipherType)
            : type(POLARSSL_CIPHER_NONE), ctx(0), iv(), tagFilter() {
        init_(cipherType);
    }

    VirgilSymmetricCipherImpl(const VirgilSymmetricCipherImpl& other)
            : type(POLARSSL_CIPHER_NONE), ctx(0), iv(), tagFilter() {
        init_(other.type);
    }

    ~VirgilSymmetricCipherImpl() {
        free_();
    }

    VirgilSymmetricCipherImpl& operator=(const VirgilSymmetricCipherImpl& rhs) {
        if (this == &rhs) {
            return *this;
        }
        free_();
        init_(rhs.type);
        return *this;
    }

private:
    void init_(cipher_type_t cipherType) {
        ctx = new cipher_context_t();
        ::cipher_init(ctx);
        type = cipherType;
        if (cipherType == POLARSSL_CIPHER_NONE) {
            return;
        }
        const cipher_info_t * info = cipher_info_from_type(cipherType);
        POLARSSL_ERROR_HANDLER_DISPOSE(
            ::cipher_init_ctx(ctx, info),
            free_()
        );
    }

    void free_() throw() {
        type = POLARSSL_CIPHER_NONE;
        if (ctx) {
            ::cipher_free(ctx);
            delete ctx;
            ctx = 0;
        }
    }

public:
    cipher_type_t type;
    cipher_context_t *ctx;
    VirgilByteArray iv;
    VirgilTagFilter tagFilter;
};

}}}

VirgilSymmetricCipher::VirgilSymmetricCipher()
        : impl_(new VirgilSymmetricCipherImpl(POLARSSL_CIPHER_NONE)) {
}

VirgilSymmetricCipher::VirgilSymmetricCipher(int type)
        : impl_(new VirgilSymmetricCipherImpl(static_cast<cipher_type_t>(type))) {
}

VirgilSymmetricCipher::VirgilSymmetricCipher(const VirgilSymmetricCipher& other)
        : impl_(new VirgilSymmetricCipherImpl(other.impl_->type)) {
}

VirgilSymmetricCipher& VirgilSymmetricCipher::operator=(const VirgilSymmetricCipher& rhs) {
    if (this == &rhs) {
        return *this;
    }
    VirgilSymmetricCipherImpl *newImpl = new VirgilSymmetricCipherImpl(rhs.impl_->type);
    if (impl_) {
        delete impl_;
    }
    impl_ = newImpl;
    return *this;
}

VirgilSymmetricCipher::~VirgilSymmetricCipher() throw() {
    if (impl_) {
        delete impl_;
        impl_ = 0;
    }
}

VirgilSymmetricCipher VirgilSymmetricCipher::aes256() {
    return VirgilSymmetricCipher(POLARSSL_CIPHER_AES_256_GCM);
}

std::string VirgilSymmetricCipher::name() const {
    checkState();
    return ::cipher_get_name(impl_->ctx);
}

size_t VirgilSymmetricCipher::blockSize() const {
    checkState();
    return ::cipher_get_block_size(impl_->ctx);
}

size_t VirgilSymmetricCipher::ivSize() const {
    checkState();
    return ::cipher_get_iv_size(impl_->ctx);
}

size_t VirgilSymmetricCipher::keySize() const {
    checkState();
    return ::cipher_get_key_size(impl_->ctx);
}

size_t VirgilSymmetricCipher::keyLength() const {
    return size_t((keySize() + 7) / 8);
}

size_t VirgilSymmetricCipher::authTagLength() const {
    checkState();
    switch (::cipher_get_cipher_mode(impl_->ctx)) {
        case POLARSSL_MODE_GCM:
            return 16;
        default:
            return 0;
    }
}

bool VirgilSymmetricCipher::isEncryptionMode() const {
    checkState();
    return ::cipher_get_operation(impl_->ctx) == POLARSSL_ENCRYPT;
}

bool VirgilSymmetricCipher::isDecryptionMode() const {
    checkState();
    return ::cipher_get_operation(impl_->ctx) == POLARSSL_DECRYPT;
}

bool VirgilSymmetricCipher::isAuthMode() const {
    checkState();
    return ::cipher_get_cipher_mode(impl_->ctx) == POLARSSL_MODE_GCM;
}

bool VirgilSymmetricCipher::isSupportPadding() const {
    checkState();
    return ::cipher_get_cipher_mode(impl_->ctx) == POLARSSL_MODE_CBC;
}

void VirgilSymmetricCipher::setEncryptionKey(const VirgilByteArray& key) {
    checkState();
    POLARSSL_ERROR_HANDLER(
        ::cipher_setkey(impl_->ctx, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(key) * 8, POLARSSL_ENCRYPT)
    );
}

void VirgilSymmetricCipher::setDecryptionKey(const VirgilByteArray& key) {
    checkState();
    POLARSSL_ERROR_HANDLER(
        ::cipher_setkey(impl_->ctx, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(key) * 8, POLARSSL_DECRYPT)
    );
}

void VirgilSymmetricCipher::setPadding(VirgilSymmetricCipherPadding padding) {
    checkState();
    cipher_padding_t paddingCode = POLARSSL_PADDING_NONE;
    switch (padding) {
        case VirgilSymmetricCipherPadding_PKCS7:
            paddingCode = POLARSSL_PADDING_PKCS7;
            break;
        case VirgilSymmetricCipherPadding_OneAndZeros:
            paddingCode = POLARSSL_PADDING_ONE_AND_ZEROS;
            break;
        case VirgilSymmetricCipherPadding_ZerosAndLen:
            paddingCode = POLARSSL_PADDING_ZEROS_AND_LEN;
            break;
        case VirgilSymmetricCipherPadding_Zeros:
            paddingCode = POLARSSL_PADDING_ZEROS;
            break;
    }
    POLARSSL_ERROR_HANDLER(::cipher_set_padding_mode(impl_->ctx, paddingCode));
}

void VirgilSymmetricCipher::setIV(const VirgilByteArray& iv) {
    checkState();
    POLARSSL_ERROR_HANDLER(
        ::cipher_set_iv(impl_->ctx, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(iv))
    );
    impl_->iv = iv;
}

void VirgilSymmetricCipher::reset() {
    checkState();
    POLARSSL_ERROR_HANDLER(::cipher_reset(impl_->ctx));
    if (cipher_get_cipher_mode(impl_->ctx) == POLARSSL_MODE_GCM) {
        POLARSSL_ERROR_HANDLER(::cipher_update_ad(impl_->ctx, NULL, 0));
    }
    if (isDecryptionMode()) {
        impl_->tagFilter.reset(blockSize());
    }
}

void VirgilSymmetricCipher::clear() {
    if (impl_) {
        VirgilSymmetricCipherImpl *newImpl = new VirgilSymmetricCipherImpl(impl_->type);
        delete impl_;
        impl_ = newImpl;
    }
}

VirgilByteArray VirgilSymmetricCipher::crypt(const VirgilByteArray& input, const VirgilByteArray& iv) {
    checkState();
    setIV(iv);
    reset();
    VirgilByteArray firstChunk = update(input);
    VirgilByteArray lastChunk = finish();

    VirgilByteArray result;
    result.insert(result.end(), firstChunk.begin(), firstChunk.end());
    result.insert(result.end(), lastChunk.begin(), lastChunk.end());

    return result;
}

VirgilByteArray VirgilSymmetricCipher::update(const VirgilByteArray& input) {
    checkState();
    size_t writtenBytes = 0;
    size_t bufLen = input.size() + this->blockSize();
    VirgilByteArray result(bufLen);

    if (isDecryptionMode() && isAuthMode()) {
        impl_->tagFilter.process(input);
        if (impl_->tagFilter.hasData()) {
            VirgilByteArray data = impl_->tagFilter.popData();
            POLARSSL_ERROR_HANDLER(
                ::cipher_update(impl_->ctx, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(data), result.data(), &writtenBytes)
            );
        }
    } else {
        POLARSSL_ERROR_HANDLER(
            ::cipher_update(impl_->ctx, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(input), result.data(), &writtenBytes)
        );
    }

    result.resize(writtenBytes);
    return result;
}

VirgilByteArray VirgilSymmetricCipher::finish() {
    checkState();
    size_t writtenBytes = 0;
    VirgilByteArray result(blockSize());
    POLARSSL_ERROR_HANDLER(
        ::cipher_finish(impl_->ctx, result.data(), &writtenBytes)
    );
    result.resize(writtenBytes);
    if (isAuthMode()) {
        if (isEncryptionMode()) {
            VirgilByteArray tag(authTagLength());
            POLARSSL_ERROR_HANDLER(
                ::cipher_write_tag(impl_->ctx, tag.data(), tag.size())
            );
            result.insert(result.end(), tag.begin(), tag.end());
        } else if (isDecryptionMode()) {
            VirgilByteArray tag = impl_->tagFilter.tag();
            POLARSSL_ERROR_HANDLER(
                ::cipher_check_tag(impl_->ctx, tag.data(), tag.size())
            );
        }
    }
    return result;
}

void VirgilSymmetricCipher::checkState() const {
    if (impl_->type == POLARSSL_CIPHER_NONE || impl_->ctx == 0 || impl_->ctx->cipher_info == 0) {
        throw VirgilCryptoException(std::string("VirgilSymmetricCipher: object has undefined algorithm.") +
                std::string(" Use one of the factory methods or method 'fromAsn1' to define cipher algorithm."));
    }
}

size_t VirgilSymmetricCipher::asn1Write(VirgilAsn1Writer& asn1Writer, size_t childWrittenBytes) const {
    checkState();
    const char *oid = 0;
    size_t oidLen;
    POLARSSL_ERROR_HANDLER(
        ::oid_get_oid_by_cipher_alg(impl_->type, &oid, &oidLen)
    );
    size_t len = 0;
    len += asn1Writer.writeOctetString(impl_->iv);
    len += asn1Writer.writeOID(std::string(oid, oidLen));
    len += asn1Writer.writeSequence(len);
    return len + childWrittenBytes;
}

void VirgilSymmetricCipher::asn1Read(VirgilAsn1Reader& asn1Reader) {
    asn1Reader.readSequence();
    std::string oid = asn1Reader.readOID();

    asn1_buf oidAsn1Buf;
    oidAsn1Buf.len = oid.size();
    oidAsn1Buf.p = reinterpret_cast<unsigned char *>(const_cast<std::string::pointer>(oid.c_str()));

    cipher_type_t type = POLARSSL_CIPHER_NONE;
    POLARSSL_ERROR_HANDLER(
        ::oid_get_cipher_alg(&oidAsn1Buf, &type)
    );

    *this = VirgilSymmetricCipher(type);
    setIV(asn1Reader.readOctetString());
}
