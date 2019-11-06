/*
 * Utilities.
 */

/*
 * Copyright © 2016-2018 The TokTok team.
 * Copyright © 2013 Tox project.
 * Copyright © 2013 plutooo
 *
 * This file is part of Tox, the free peer to peer instant messenger.
 * This file is donated to the Tox Project.
 *
 * Tox is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Tox is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Tox.  If not, see <http://www.gnu.org/licenses/>.
 */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifndef _XOPEN_SOURCE
#define _XOPEN_SOURCE 600
#endif

#include "util.h"

#include "crypto_core.h" /* for CRYPTO_PUBLIC_KEY_SIZE */

#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <time.h>

#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <sys/errno.h>

#include "TCP_client.h"
#include "TCP_server.h"
#include "crypto_core.h"
#include "mono_time.h"
#include "network.h"


/* id functions */
bool id_equal(const uint8_t *dest, const uint8_t *src)
{
    return public_key_cmp(dest, src) == 0;
}

uint32_t id_copy(uint8_t *dest, const uint8_t *src)
{
    memcpy(dest, src, CRYPTO_PUBLIC_KEY_SIZE);
    return CRYPTO_PUBLIC_KEY_SIZE;
}

void host_to_net(uint8_t *num, uint16_t numbytes)
{
#ifndef WORDS_BIGENDIAN
    uint32_t i;
    VLA(uint8_t, buff, numbytes);

    for (i = 0; i < numbytes; ++i) {
        buff[i] = num[numbytes - i - 1];
    }

    memcpy(num, buff, numbytes);
#endif
}

void net_to_host(uint8_t *num, uint16_t numbytes)
{
    host_to_net(num, numbytes);
}

int create_recursive_mutex(pthread_mutex_t *mutex)
{
    pthread_mutexattr_t attr;

    if (pthread_mutexattr_init(&attr) != 0) {
        return -1;
    }

    if (pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE) != 0) {
        pthread_mutexattr_destroy(&attr);
        return -1;
    }

    /* Create queue mutex */
    if (pthread_mutex_init(mutex, &attr) != 0) {
        pthread_mutexattr_destroy(&attr);
        return -1;
    }

    pthread_mutexattr_destroy(&attr);

    return 0;
}

int16_t max_s16(int16_t a, int16_t b)
{
    return a > b ? a : b;
}
int32_t max_s32(int32_t a, int32_t b)
{
    return a > b ? a : b;
}
int64_t max_s64(int64_t a, int64_t b)
{
    return a > b ? a : b;
}

int16_t min_s16(int16_t a, int16_t b)
{
    return a < b ? a : b;
}
int32_t min_s32(int32_t a, int32_t b)
{
    return a < b ? a : b;
}
int64_t min_s64(int64_t a, int64_t b)
{
    return a < b ? a : b;
}

uint16_t max_u16(uint16_t a, uint16_t b)
{
    return a > b ? a : b;
}
uint32_t max_u32(uint32_t a, uint32_t b)
{
    return a > b ? a : b;
}
uint64_t max_u64(uint64_t a, uint64_t b)
{
    return a > b ? a : b;
}

uint16_t min_u16(uint16_t a, uint16_t b)
{
    return a < b ? a : b;
}
uint32_t min_u32(uint32_t a, uint32_t b)
{
    return a < b ? a : b;
}
uint64_t min_u64(uint64_t a, uint64_t b)
{
    return a < b ? a : b;
}

uint64_t get_unixtime() {
	struct timeval tv;
	gettimeofday(&tv,nullptr);
	return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

int64_t local_msg_id() {
	uint64_t uuid = 0;
	uint64_t unixtime = get_unixtime();
	uint64_t max_12_bit_num = 4096;
	uint64_t rand_num = (rand() % (max_12_bit_num));
	static uint64_t seq_num = 0;
	uuid |= seq_num;
	uuid |= (rand_num << 10); 
	uuid |= (unixtime << 22); 
	seq_num += 1;
	return uuid;
}

void nano_sleep(uint32_t milliseconds)
{
#if defined(_WIN32) || defined(__WIN32__) || defined(WIN32)
    Sleep(x);
#else
    struct timespec req;
    req.tv_sec = milliseconds / 1000;
    req.tv_nsec = (long)milliseconds % 1000 * 1000 * 1000;
    nanosleep(&req, nullptr);
#endif
}

bool SetNoBlock(int nSocket, bool bNotBlock)
{
    int flags = fcntl(nSocket, F_GETFL, 0);
    if(bNotBlock)
        flags |= O_NONBLOCK;
    else
        flags &= (~O_NONBLOCK);
    fcntl(nSocket, F_SETFL, flags);
    
    return true;
}

int StringToHex(const char *str, unsigned char *out, unsigned int *outlen)
{
    const char *p = str;
    char high = 0, low = 0;
    int tmplen = (int)strlen(p);
    int cnt = 0;

    while(cnt < (tmplen / 2))
    {
        high = ((*p > '9') && ((*p <= 'F') || (*p <= 'f'))) ? *p - 48 - 7 : *p - 48;
        low = (*(++ p) > '9' && ((*p <= 'F') || (*p <= 'f'))) ? *(p) - 48 - 7 : *(p) - 48;
        out[cnt] = ((high & 0x0f) << 4 | (low & 0x0f));
        p ++;
        cnt ++;
    }
    if(tmplen % 2 != 0) out[cnt] = ((*p > '9') && ((*p <= 'F') || (*p <= 'f'))) ? *p - 48 - 7 : *p - 48;
    
    if(outlen != NULL) *outlen = tmplen / 2 + tmplen % 2;
    return tmplen / 2 + tmplen % 2;
}

int HexToString(unsigned char *buf, unsigned int buflen, char *out)
{
    char strBuf[33] = {0};
    char pbuf[32];
    int i;
    for(i = 0; i < buflen; i++)
    {
        strncat(strBuf, pbuf, 2);
    }
    strncpy(out, strBuf, buflen * 2);
    return buflen * 2;
}

enum NET_ERR_CODE
{
    NET_SUCCEED = 0,
    NET_FAILURE,
    NET_ERR_CREATE_SOCKET,
    NET_ERR_SET_BOLOCK,
    NET_ERR_GET_IPPORT,
    NET_ERR_ERRNO,
    NET_ERR_CONNECT,
    NET_ERR_GETSOCKOPT,
    NET_ERR_SETSOCKOPT,
    NET_ERR_NOSIGPIPE,
    NET_ERR_TIMEOUT,
    NET_ERR_SEND,
    NET_ERR_RECV,
    NET_ERR_PUBLIC_KEY,
    NET_ERR_NEW_LOG,
    NET_ERR_NEW_DHT,
};

int IsSocks5(char *szHost, int nPort, int nWaitSeconds)
{
     //socks5 protocol desc
     //|--------|-------------|-------------|
     //|  VER   |   NMETHOD   |   METHODS   |
     //|--------|-------------|-------------|
     //|   1    |      1      |    1-255    |
     //|--------|-------------|-------------|
     //VER socks5 version is 0x05.

    
    int nSize = 0;
    const int MaxBuffLen = 100;
    char szSendMsg[MaxBuffLen];
    int64_t lBeginTime = get_unixtime();
    
    szSendMsg[nSize++] = 0x05;
    szSendMsg[nSize++] = 0x01;
    szSendMsg[nSize++] = 0xFF;

    Socket sock;
    sock.socket = (int)socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if(sock.socket == -1)
        return NET_ERR_CREATE_SOCKET;

//    struct sockaddr_in saddr;
//    memset(&saddr, 0, sizeof(saddr));
//    saddr.sin_family = AF_INET;
//    saddr.sin_addr.s_addr = inet_addr(szIP);
//    saddr.sin_port = htons(nPort);
    
    if (nWaitSeconds > 0)
    {
        if (!SetNoBlock(sock.socket,true))
        {
            kill_sock(sock);
            return NET_ERR_SET_BOLOCK;
        }

    }
    
    IP_Port *pIPInfo = NULL;
    const int32_t count = net_getipport(szHost, &pIPInfo, TOX_SOCK_STREAM);
    if (count == -1)
    {
        kill_sock(sock);
        net_freeipport(pIPInfo);
        return NET_ERR_GET_IPPORT;
    }
    
    pIPInfo->port = net_htons(nPort);
    int nRet = net_connect(sock, *pIPInfo);
    if(nRet < 0)
    {
        if(errno != EINPROGRESS && errno != EWOULDBLOCK)
        {
            kill_sock(sock);
            net_freeipport(pIPInfo);
            return NET_ERR_ERRNO;
        }
 
        struct timeval tv;
        tv.tv_sec = nWaitSeconds;
        tv.tv_usec = 0;
        fd_set wset;
        FD_ZERO(&wset);
        FD_SET(sock.socket,&wset);
        nRet = select(sock.socket+1, NULL, &wset, NULL, &tv);
        if (nRet == 1)
        {
            /*
             nRet returns 1 (indicating that the socket is writable).
             There are two possible scenarios: successful connection establishment or socket error.
             The error message is not saved to the errno variable, so getsockopt needs to be called.
             */
            int err = 0;
            socklen_t len = sizeof(err);
            nRet = getsockopt(sock.socket, SOL_SOCKET, SO_ERROR, &err, &len);
            if (nRet == 0 && err != 0)
            {
                kill_sock(sock);
                net_freeipport(pIPInfo);
                return NET_ERR_GETSOCKOPT;
            }
        }
        else
        {
            /*
            nRet == 0 timeout
            nRet < 0 select err
            */
            kill_sock(sock);
            net_freeipport(pIPInfo);
            return NET_ERR_CONNECT;
        }
    }
    
    if (nWaitSeconds > 0)
    {
        if (!SetNoBlock(sock.socket,false))
        {
            kill_sock(sock);
            net_freeipport(pIPInfo);
            return NET_ERR_SET_BOLOCK;
        }
    }
    
    if (!set_socket_nosigpipe(sock))
    {
        kill_sock(sock);
        net_freeipport(pIPInfo);
        return NET_ERR_NOSIGPIPE;
    }
    
    int64_t lRunTime = get_unixtime() - lBeginTime;
    int64_t nRemainMilliseconds = nWaitSeconds * 1000 - lRunTime;
    
    if (nRemainMilliseconds <= 0)
    {
        kill_sock(sock);
        net_freeipport(pIPInfo);
        return NET_ERR_TIMEOUT;
    }
    
    struct timeval tv_out;
    tv_out.tv_sec = nRemainMilliseconds / 1000;
    tv_out.tv_usec = nRemainMilliseconds % 1000 * 1000;
    if(setsockopt(sock.socket, SOL_SOCKET, SO_SNDTIMEO, &tv_out, sizeof(tv_out)) != 0)
    {
        kill_sock(sock);
        net_freeipport(pIPInfo);
        return NET_ERR_SETSOCKOPT;
    }
    
    if (nSize != send(sock.socket, (const char*)szSendMsg, nSize, 0))
    {
        kill_sock(sock);
        net_freeipport(pIPInfo);
        return NET_ERR_SETSOCKOPT;
    }

    lRunTime = get_unixtime() - lBeginTime;
    nRemainMilliseconds = nWaitSeconds * 1000 - lRunTime;
    
    if (nRemainMilliseconds <= 0)
    {
        kill_sock(sock);
        net_freeipport(pIPInfo);
        return NET_ERR_SEND;
    }
    
    tv_out.tv_sec = nRemainMilliseconds / 1000;
    tv_out.tv_usec = nRemainMilliseconds % 1000 * 1000;
    if(setsockopt(sock.socket, SOL_SOCKET, SO_RCVTIMEO, &tv_out, sizeof(tv_out)) != 0)
    {
        kill_sock(sock);
        net_freeipport(pIPInfo);
        return NET_ERR_SETSOCKOPT;
    }
    
    char szRecvMsg[MaxBuffLen];
    int nRecvSize = (int)recv(sock.socket, (char*)szRecvMsg, sizeof((const char*)szRecvMsg), MaxBuffLen);
    
    int nRetCode = NET_FAILURE;
    if (nRecvSize > 0 && szRecvMsg[0] == 0x05)
       nRetCode = NET_SUCCEED;
    
    kill_sock(sock);
    net_freeipport(pIPInfo);
    
    return nRetCode;
}

int probe_node_tcp(const char *szHost, int nPort, const char *szPublicKey, int nWaitMilliseconds)
{
    uint8_t self_public_key[CRYPTO_PUBLIC_KEY_SIZE];
    uint8_t self_secret_key[CRYPTO_SECRET_KEY_SIZE];
    crypto_new_keypair(self_public_key, self_secret_key);

    const int nPublicKeySize = CRYPTO_PUBLIC_KEY_SIZE * 2;
    char szTmpPulbicKey[nPublicKeySize + 1];
    memset(szTmpPulbicKey, 0, sizeof(szTmpPulbicKey));
    memcpy(szTmpPulbicKey, szPublicKey, nPublicKeySize);
    
    uint8_t f_public_key[CRYPTO_PUBLIC_KEY_SIZE];
    unsigned int key_len = CRYPTO_PUBLIC_KEY_SIZE;
    StringToHex(szTmpPulbicKey,f_public_key, &key_len);
    
    if (key_len != CRYPTO_PUBLIC_KEY_SIZE)
        return NET_ERR_PUBLIC_KEY;
    
    IP_Port *pIPInfo = NULL;
    const int32_t count = net_getipport(szHost, &pIPInfo, TOX_SOCK_DGRAM);
    if (count == -1)
    {
        net_freeipport(pIPInfo);
        return NET_ERR_GET_IPPORT;
    }
    
    pIPInfo->port = net_htons(nPort);
    Mono_Time *mono_time = mono_time_new();
    TCP_Client_Connection *conn = new_TCP_connection(mono_time, *pIPInfo, f_public_key, self_public_key, self_secret_key, nullptr);
   
    // Run the client's main loop but not the server.
    int nCount = 0;
    const int nInterval = 50;
    TCP_Client_Status nStatus = TCP_CLIENT_NO_STATUS;
    while (nCount < nWaitMilliseconds)
    {
        nCount += nInterval;
        mono_time_update(mono_time);
        do_TCP_connection(mono_time, conn, nullptr);
        nano_sleep(nInterval);
       
        nStatus = tcp_con_status(conn);
        if(nStatus == TCP_CLIENT_CONFIRMED || nStatus == TCP_CLIENT_DISCONNECTED)
            break;
    }
    
    net_freeipport(pIPInfo);
    kill_TCP_connection(conn);
    mono_time_free(mono_time);

    int nRetCode = NET_FAILURE;
    if (nStatus == TCP_CLIENT_CONFIRMED)
        nRetCode = NET_SUCCEED;
    
    return nRetCode;
}

/* Create new UDP connection to ip_port/public_key
 */
int new_UDP_connection(const Mono_Time *mono_time, IP_Port ip_port, const uint8_t *public_key,
        const uint8_t *self_public_key, const uint8_t *self_secret_key)
{
    if (networking_at_startup() != 0)
        return 0;
    

    if (!net_family_is_ipv4(ip_port.ip.family) && !net_family_is_ipv6(ip_port.ip.family))
        return 0;
    

    Family family = ip_port.ip.family;
    Socket sock = net_socket(family, TOX_SOCK_DGRAM, TOX_PROTO_UDP);

    if (!sock_valid(sock))
        return 0;

    if (!set_socket_nosigpipe(sock))
    {
        kill_sock(sock);
        return 0;
    }

    if (!(set_socket_nonblock(sock)))
    {
        kill_sock(sock);
        return 0;
    }
    
    
    if(!bind_to_port(sock, family,ip_port.port))
    {
        kill_sock(sock);
        return 0;
    }

    return sock.socket;
}


int probe_node_udp(const char *szHost, int nPort, const char *szPublicKey, int nWaitMilliseconds)
{
    uint8_t self_public_key[CRYPTO_PUBLIC_KEY_SIZE];
    uint8_t self_secret_key[CRYPTO_SECRET_KEY_SIZE];
    crypto_new_keypair(self_public_key, self_secret_key);

    const int nPublicKeySize = CRYPTO_PUBLIC_KEY_SIZE * 2;
    char szTmpPulbicKey[nPublicKeySize + 1];
    memset(szTmpPulbicKey, 0, sizeof(szTmpPulbicKey));
    memcpy(szTmpPulbicKey, szPublicKey, nPublicKeySize);
    
    uint8_t f_public_key[CRYPTO_PUBLIC_KEY_SIZE];
    unsigned int key_len = CRYPTO_PUBLIC_KEY_SIZE;
    StringToHex(szTmpPulbicKey,f_public_key, &key_len);
    
    if (key_len != CRYPTO_PUBLIC_KEY_SIZE)
        return NET_ERR_NEW_LOG;
    
    IP_Port *pIPInfo = NULL;
    const int32_t count = net_getipport(szHost, &pIPInfo, TOX_SOCK_DGRAM);
    if (count == -1)
    {
        net_freeipport(pIPInfo);
        return false;
    }
    
    pIPInfo->port = net_htons(nPort);
    
    IP ip4;
    ip_init(&ip4, 0);
    
    Logger *pLog = logger_new();
    if (pLog == nullptr)
        return NET_ERR_NEW_LOG;
    
    Networking_Core *pNet = new_networking(pLog, ip4, pIPInfo->port);
    
    if (pNet == nullptr)
    {
        logger_kill(pLog);
        net_freeipport(pIPInfo);
        return NET_ERR_GET_IPPORT;
    }
    
    Mono_Time *mono_time = mono_time_new();
    DHT *pDht = new_dht(pLog, mono_time, pNet, false, self_public_key, self_secret_key);
    if (pNet == nullptr)
    {
        kill_networking(pNet);
        net_freeipport(pIPInfo);
        mono_time_free(mono_time);
        logger_kill(pLog);
        return NET_ERR_NEW_DHT;
    }
    
    dht_getnodes(pDht, pIPInfo, f_public_key, self_public_key);
    
    int nRet = NET_FAILURE;
    if (networking_test(pNet, *pIPInfo, nWaitMilliseconds))
        nRet = NET_SUCCEED;
    
    kill_networking(pNet);
    net_freeipport(pIPInfo);
    mono_time_free(mono_time);
    logger_kill(pLog);
    
    return nRet;
}

int TestNode(const char *szHost, int nPort, bool bTcp, const char *szPublicKey, int nWaitSeconds)
{
    if (bTcp)
       return probe_node_tcp(szHost, nPort, szPublicKey, nWaitSeconds * 1000);
    
    return probe_node_udp(szHost, nPort, szPublicKey, nWaitSeconds * 1000);;
}

char* GetUrl(char *szUrlAddress, int nMaxLen, time_t mkTime)
{
    if (mkTime == 0)
        mkTime = time(0);
    char szUrl[nUrlLen + 1];
    memset(szUrl, 0, sizeof(szUrl));
    
    return szUrlAddress;
}


