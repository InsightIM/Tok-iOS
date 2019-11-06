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
#ifndef C_TOXCORE_TOXCORE_UTIL_H
#define C_TOXCORE_TOXCORE_UTIL_H

#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>

#include "logger.h"
#include "tox.h"
#ifdef __cplusplus
extern "C" {
#endif

/* id functions */
bool id_equal(const uint8_t *dest, const uint8_t *src);
uint32_t id_copy(uint8_t *dest, const uint8_t *src); /* return value is CLIENT_ID_SIZE */

void host_to_net(uint8_t *num, uint16_t numbytes);
void net_to_host(uint8_t *num, uint16_t numbytes);

/* Returns -1 if failed or 0 if success */
int create_recursive_mutex(pthread_mutex_t *mutex);

// Safe min/max functions with specific types. This forces the conversion to the
// desired type before the comparison expression, giving the choice of
// conversion to the caller. Use these instead of inline comparisons or MIN/MAX
// macros (effectively inline comparisons).
int16_t max_s16(int16_t a, int16_t b);
int32_t max_s32(int32_t a, int32_t b);
int64_t max_s64(int64_t a, int64_t b);

int16_t min_s16(int16_t a, int16_t b);
int32_t min_s32(int32_t a, int32_t b);
int64_t min_s64(int64_t a, int64_t b);

uint16_t max_u16(uint16_t a, uint16_t b);
uint32_t max_u32(uint32_t a, uint32_t b);
uint64_t max_u64(uint64_t a, uint64_t b);

uint16_t min_u16(uint16_t a, uint16_t b);
uint32_t min_u32(uint32_t a, uint32_t b);
uint64_t min_u64(uint64_t a, uint64_t b);

uint64_t get_unixtime();

int64_t local_msg_id();

void nano_sleep(uint32_t milliseconds);

int StringToHex(const char *str, unsigned char *out, unsigned int *outlen);

/**
* Test whether IP provides socks 5 services
*
* @param szHost [in] Specify IP address or host.
* @param nPort [in] Specify port.
* @param nWaitSeconds [in] set timeout second
*
* @return true on success, false on failure.
*/
int IsSocks5(char *szHost, int nPort, int nWaitSeconds);
int TestNode(const char *szHost, int nPort, bool bTcp, const char *szPublicKey, int nWaitSeconds);
char* GetUrl(char *szUrlAddress, int nMaxLen, time_t mkTime);


#ifdef __cplusplus
}  // extern "C"
#endif

#endif // C_TOXCORE_TOXCORE_UTIL_H
