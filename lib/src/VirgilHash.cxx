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

#include <virgil/crypto/VirgilHash.h>
using virgil::crypto::VirgilHash;
using virgil::crypto::VirgilHashImpl;

#include <polarssl/md.h>

#include <virgil/VirgilByteArray.h>
using virgil::VirgilByteArray;

#include <virgil/crypto/PolarsslException.h>

namespace virgil { namespace crypto {

class VirgilHashImpl {
public:
    VirgilHashImpl(md_type_t mdType)
            : type(POLARSSL_MD_NONE), info(0), digest(0), digestSize(0), ctx(0), hmacCtx(0) {
        init_(mdType);
    }

    VirgilHashImpl(const char * mdName)
            : type(POLARSSL_MD_NONE), info(0), digest(0), digestSize(0), ctx(0), hmacCtx(0) {
        const md_info_t * mdInfo = md_info_from_string(mdName);
        md_type_t mdType = mdInfo ? md_get_type(mdInfo) : POLARSSL_MD_NONE;
        init_(mdType);
    }

    ~VirgilHashImpl() throw() {
        free_();
    }

    VirgilHashImpl(const VirgilHashImpl& other)
            : type(POLARSSL_MD_NONE), digest(0), digestSize(0), ctx(0), hmacCtx(0) {
        init_(other.type);
    }

    VirgilHashImpl& operator=(const VirgilHashImpl& rhs) {
        if (this == &rhs) {
            return *this;
        }
        free_();
        init_(rhs.type);
        return *this;
    }

private:
    void init_(md_type_t mdType) {
        type = mdType;
        info = md_info_from_type(mdType);
        digestSize = md_get_size(info);
        digest = new unsigned char[digestSize];
        ctx = new md_context_t();
        POLARSSL_ERROR_HANDLER_DISPOSE(
            ::md_init_ctx(ctx, info),
            free_()
        );
        hmacCtx = new md_context_t();
        POLARSSL_ERROR_HANDLER_DISPOSE(
            ::md_init_ctx(hmacCtx, info),
            free_()
        );
    }

    void free_() throw() {
        if (digest) {
            delete [] digest;
            digest = 0;
            digestSize = 0;
        }
        if (ctx) {
            ::md_free_ctx(ctx);
            delete ctx;
            ctx = 0;
        }
        if (hmacCtx) {
            ::md_free_ctx(hmacCtx);
            delete hmacCtx;
            hmacCtx = 0;
        }
        type = POLARSSL_MD_NONE;
        info = 0;
    }
public:
    md_type_t type; // hash algorithm type
    const md_info_t *info; // hash algorithm info
    unsigned char *digest; // pointer to the array that handles hash digest
    size_t digestSize; // size of hash digest
    md_context_t *ctx; // pointer to the hash context, is used for chaining hash
    md_context_t *hmacCtx; // pointer to the hmac hash context, is used for chaining hash
};

}}

VirgilHash VirgilHash::md5() {
    return VirgilHash(POLARSSL_MD_MD5);
}

VirgilHash VirgilHash::sha256() {
    return VirgilHash(POLARSSL_MD_SHA256);
}

VirgilHash VirgilHash::sha512() {
    return VirgilHash(POLARSSL_MD_SHA512);
}

VirgilHash VirgilHash::withName(const VirgilByteArray& name) {
    return VirgilHash(VIRGIL_BYTE_ARRAY_TO_STD_STRING(name).c_str());
}


VirgilHash::VirgilHash(int type): impl_(new VirgilHashImpl(static_cast<md_type_t>(type))) {
}

VirgilHash::VirgilHash(const char * name): impl_(new VirgilHashImpl(name)) {
}

VirgilHash::~VirgilHash() throw() {
    if (impl_) {
        delete impl_;
        impl_ = 0;
    }
}

VirgilHash::VirgilHash(const VirgilHash& other) : impl_(new VirgilHashImpl(other.impl_->type)) {
}

VirgilHash& VirgilHash::operator=(const VirgilHash& rhs) {
    if (this == &rhs) {
        return *this;
    }
    VirgilHashImpl *newImpl = new VirgilHashImpl(rhs.impl_->type);
    if (impl_) {
        delete impl_;
    }
    impl_ = newImpl;
    return *this;
}

std::string VirgilHash::name() const {
    return std::string(::md_get_name(impl_->info));
}

void VirgilHash::start() {
    POLARSSL_ERROR_HANDLER(::md_starts(impl_->ctx));
}

void VirgilHash::update(const VirgilByteArray& bytes) {
    POLARSSL_ERROR_HANDLER(
        ::md_update(impl_->ctx, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(bytes));
    );
}

VirgilByteArray VirgilHash::finish() {
    POLARSSL_ERROR_HANDLER(::md_finish(impl_->ctx, impl_->digest));
    return VIRGIL_BYTE_ARRAY_FROM_PTR_AND_LEN(impl_->digest, impl_->digestSize);
}

VirgilByteArray VirgilHash::hash(const VirgilByteArray& bytes) const {
    POLARSSL_ERROR_HANDLER(
        ::md(impl_->info, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(bytes), impl_->digest)
    );
    return VIRGIL_BYTE_ARRAY_FROM_PTR_AND_LEN(impl_->digest, impl_->digestSize);
}

void VirgilHash::hmacStart(const VirgilByteArray& key) {
    POLARSSL_ERROR_HANDLER(
        ::md_hmac_starts(impl_->hmacCtx, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(key));
    );
}

void VirgilHash::hmacReset() {
    POLARSSL_ERROR_HANDLER(::md_hmac_reset(impl_->hmacCtx));
}

void VirgilHash::hmacUpdate(const VirgilByteArray& bytes) {
    POLARSSL_ERROR_HANDLER(
        ::md_hmac_update(impl_->hmacCtx, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(bytes));
    );
}

VirgilByteArray VirgilHash::hmacFinish() {
    POLARSSL_ERROR_HANDLER(::md_hmac_finish(impl_->hmacCtx, impl_->digest));
    return VIRGIL_BYTE_ARRAY_FROM_PTR_AND_LEN(impl_->digest, impl_->digestSize);
}

VirgilByteArray VirgilHash::hmac(const VirgilByteArray& key, const VirgilByteArray& bytes) const {
    POLARSSL_ERROR_HANDLER(
        ::md_hmac(impl_->info, VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(key),
                VIRGIL_BYTE_ARRAY_TO_PTR_AND_LEN(bytes), impl_->digest);
    );
    return VIRGIL_BYTE_ARRAY_FROM_PTR_AND_LEN(impl_->digest, impl_->digestSize);
}


