/*
 * The Tox public API.
 */

/*
 * Copyright © 2016-2018 The TokTok team.
 * Copyright © 2013 Tox project.
 *
 * This file is part of Tox, the free peer to peer instant messenger.
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

#include "tox.h"

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "Messenger.h"
#include "group.h"
#include "logger.h"
#include "mono_time.h"
#include "timer.h"
#include "util.h"

#include "../toxencryptsave/defines.h"

#define SET_ERROR_PARAMETER(param, x) do { if (param) { *param = x; } } while (0)

#if TOX_HASH_LENGTH != CRYPTO_SHA256_SIZE
#error "TOX_HASH_LENGTH is assumed to be equal to CRYPTO_SHA256_SIZE"
#endif

#if FILE_ID_LENGTH != CRYPTO_SYMMETRIC_KEY_SIZE
#error "FILE_ID_LENGTH is assumed to be equal to CRYPTO_SYMMETRIC_KEY_SIZE"
#endif

#if TOX_FILE_ID_LENGTH != CRYPTO_SYMMETRIC_KEY_SIZE
#error "TOX_FILE_ID_LENGTH is assumed to be equal to CRYPTO_SYMMETRIC_KEY_SIZE"
#endif

#if TOX_FILE_ID_LENGTH != TOX_HASH_LENGTH
#error "TOX_FILE_ID_LENGTH is assumed to be equal to TOX_HASH_LENGTH"
#endif

#if TOX_PUBLIC_KEY_SIZE != CRYPTO_PUBLIC_KEY_SIZE
#error "TOX_PUBLIC_KEY_SIZE is assumed to be equal to CRYPTO_PUBLIC_KEY_SIZE"
#endif

#if TOX_SECRET_KEY_SIZE != CRYPTO_SECRET_KEY_SIZE
#error "TOX_SECRET_KEY_SIZE is assumed to be equal to CRYPTO_SECRET_KEY_SIZE"
#endif

#if TOX_MAX_NAME_LENGTH != MAX_NAME_LENGTH
#error "TOX_MAX_NAME_LENGTH is assumed to be equal to MAX_NAME_LENGTH"
#endif

#if TOX_MAX_STATUS_MESSAGE_LENGTH != MAX_STATUSMESSAGE_LENGTH
#error "TOX_MAX_STATUS_MESSAGE_LENGTH is assumed to be equal to MAX_STATUSMESSAGE_LENGTH"
#endif

struct Tox {
    Messenger *m;
    Mono_Time *mono_time;
	BS_List timer;

    tox_self_connection_status_cb *self_connection_status_callback;
    tox_friend_name_cb *friend_name_callback;
    tox_friend_status_message_cb *friend_status_message_callback;
    tox_friend_status_cb *friend_status_callback;
    tox_friend_connection_status_cb *friend_connection_status_callback;
    tox_friend_typing_cb *friend_typing_callback;
    tox_friend_read_receipt_cb *friend_read_receipt_callback;
    tox_friend_request_cb *friend_request_callback;
    tox_friend_message_cb *friend_message_callback;
    tox_group_message_cb *group_message_callback;
    tox_stranger_message_cb *stranger_message_callback;
    tox_user_add_cb *user_add_callback;
    tox_friend_message_offline_cb *friend_message_offline_callback;
	tox_event_timer_cb *event_timer_callback;
    tox_file_recv_control_cb *file_recv_control_callback;
    tox_file_chunk_request_cb *file_chunk_request_callback;
    tox_file_recv_cb *file_recv_callback;
    tox_file_recv_chunk_cb *file_recv_chunk_callback;
    tox_conference_invite_cb *conference_invite_callback;
    tox_conference_connected_cb *conference_connected_callback;
    tox_conference_message_cb *conference_message_callback;
    tox_conference_title_cb *conference_title_callback;
    tox_conference_peer_name_cb *conference_peer_name_callback;
    tox_conference_peer_list_changed_cb *conference_peer_list_changed_callback;
    tox_friend_lossy_packet_cb *friend_lossy_packet_callback;
    tox_friend_lossless_packet_cb *friend_lossless_packet_callback;
};

struct Tox_Userdata {
    Tox *tox;
    void *user_data;
};

static void tox_self_connection_status_handler(Messenger *m, unsigned int connection_status, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->self_connection_status_callback != nullptr) {
        tox_data->tox->self_connection_status_callback(tox_data->tox, (Tox_Connection)connection_status, tox_data->user_data);
    }
}

static void tox_friend_name_handler(Messenger *m, uint32_t friend_number, const uint8_t *name, size_t length,
                                    void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_name_callback != nullptr) {
        tox_data->tox->friend_name_callback(tox_data->tox, friend_number, name, length, tox_data->user_data);
    }
}

static void tox_friend_status_message_handler(Messenger *m, uint32_t friend_number, const uint8_t *message,
        size_t length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_status_message_callback != nullptr) {
        tox_data->tox->friend_status_message_callback(tox_data->tox, friend_number, message, length, tox_data->user_data);
    }
}

static void tox_friend_status_handler(Messenger *m, uint32_t friend_number, unsigned int status, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_status_callback != nullptr) {
        tox_data->tox->friend_status_callback(tox_data->tox, friend_number, (Tox_User_Status)status, tox_data->user_data);
    }
}

static void tox_friend_connection_status_handler(Messenger *m, uint32_t friend_number, unsigned int connection_status,
        void *user_data)
{
    if (user_data == NULL) {
        return;
    }
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_connection_status_callback != nullptr) {
        tox_data->tox->friend_connection_status_callback(tox_data->tox, friend_number, (Tox_Connection)connection_status,
                tox_data->user_data);
    }
}

static void tox_friend_typing_handler(Messenger *m, uint32_t friend_number, bool is_typing, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_typing_callback != nullptr) {
        tox_data->tox->friend_typing_callback(tox_data->tox, friend_number, is_typing, tox_data->user_data);
    }
}

static void tox_friend_read_receipt_handler(Messenger *m, uint32_t friend_number, uint32_t message_id, int64_t local_msg_id, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_read_receipt_callback != nullptr) {
        tox_data->tox->friend_read_receipt_callback(tox_data->tox, friend_number, message_id, local_msg_id, tox_data->user_data);
    }
}

static void tox_friend_request_handler(Messenger *m, const uint8_t *public_key, const uint8_t *message, size_t length,
                                       void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_request_callback != nullptr) {
        tox_data->tox->friend_request_callback(tox_data->tox, public_key, message, length, tox_data->user_data);
    }
}

static void tox_friend_message_handler(Messenger *m, uint32_t friend_number, unsigned int type, const uint8_t *message,
                                       size_t length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_message_callback != nullptr) {
        tox_data->tox->friend_message_callback(tox_data->tox, friend_number, (Tox_Message_Type)type, message, length,
                                               tox_data->user_data);
    }
}

static void tox_friend_message_offline_handler(Messenger *m, uint32_t friend_number, unsigned int cmd, const uint8_t *message,
                                       size_t length, uint8_t device_type, uint32_t version_code, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_message_offline_callback != nullptr) {
        tox_data->tox->friend_message_offline_callback(tox_data->tox, friend_number, (TOX_MESSAGE_OFFLINE_CMD)cmd, message, length,
                                               device_type, version_code, tox_data->user_data);
    }
}

static void tox_group_message_handler(Messenger *m, uint32_t friend_number, unsigned int cmd, const uint8_t *message,
                                       size_t length, uint8_t device_type, uint32_t version_code, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->group_message_callback != nullptr) {
        tox_data->tox->group_message_callback(tox_data->tox, friend_number, (TOX_MESSAGE_GROUP_CMD)cmd, message, length,
                                               device_type, version_code, tox_data->user_data);
    }
}

static void tox_stranger_message_handler(Messenger *m, uint32_t friend_number, unsigned int cmd, const uint8_t *message,
                                       size_t length, uint8_t device_type, uint32_t version_code, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->stranger_message_callback != nullptr) {
        tox_data->tox->stranger_message_callback(tox_data->tox, friend_number, (TOX_MESSAGE_GROUP_CMD)cmd, message, length,
                                               device_type, version_code, tox_data->user_data);
    }
}

static void tox_user_add_handler(Messenger *m, uint32_t friend_number, uint64_t last_seen_time, void *user_data)
{
    struct Tox *tox = (struct Tox *)user_data;

    if (tox && tox->user_add_callback != nullptr) {
        tox->user_add_callback(tox, friend_number, last_seen_time, nullptr);
    }
}

static void tox_file_recv_control_handler(Messenger *m, uint32_t friend_number, uint32_t file_number,
        unsigned int control, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->file_recv_control_callback != nullptr) {
        tox_data->tox->file_recv_control_callback(tox_data->tox, friend_number, file_number, (Tox_File_Control)control,
                tox_data->user_data);
    }
}

static void tox_file_chunk_request_handler(Messenger *m, uint32_t friend_number, uint32_t file_number,
        uint64_t position, size_t length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->file_chunk_request_callback != nullptr) {
        tox_data->tox->file_chunk_request_callback(tox_data->tox, friend_number, file_number, position, length,
                tox_data->user_data);
    }
}

static void tox_file_recv_handler(Messenger *m, uint32_t friend_number, uint32_t file_number, uint32_t kind,
                                  uint64_t file_size, const uint8_t *filename, size_t filename_length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->file_recv_callback != nullptr) {
        tox_data->tox->file_recv_callback(tox_data->tox, friend_number, file_number, kind, file_size, filename, filename_length,
                                          tox_data->user_data);
    }
}

static void tox_file_recv_chunk_handler(Messenger *m, uint32_t friend_number, uint32_t file_number, uint64_t position,
                                        const uint8_t *data, size_t length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->file_recv_chunk_callback != nullptr) {
        tox_data->tox->file_recv_chunk_callback(tox_data->tox, friend_number, file_number, position, data, length,
                                                tox_data->user_data);
    }
}

static void tox_conference_invite_handler(Messenger *m, uint32_t friend_number, int type, const uint8_t *cookie,
        size_t length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->conference_invite_callback != nullptr) {
        tox_data->tox->conference_invite_callback(tox_data->tox, friend_number, (Tox_Conference_Type)type, cookie, length,
                tox_data->user_data);
    }
}

static void tox_conference_connected_handler(Messenger *m, uint32_t conference_number, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->conference_connected_callback != nullptr) {
        tox_data->tox->conference_connected_callback(tox_data->tox, conference_number, tox_data->user_data);
    }
}

static void tox_conference_message_handler(Messenger *m, uint32_t conference_number, uint32_t peer_number, int type,
        const uint8_t *message, size_t length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->conference_message_callback != nullptr) {
        tox_data->tox->conference_message_callback(tox_data->tox, conference_number, peer_number, (Tox_Message_Type)type,
                message, length, tox_data->user_data);
    }
}

static void tox_conference_title_handler(Messenger *m, uint32_t conference_number, uint32_t peer_number,
        const uint8_t *title, size_t length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->conference_title_callback != nullptr) {
        tox_data->tox->conference_title_callback(tox_data->tox, conference_number, peer_number, title, length,
                tox_data->user_data);
    }
}

static void tox_conference_peer_name_handler(Messenger *m, uint32_t conference_number, uint32_t peer_number,
        const uint8_t *name, size_t length, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->conference_peer_name_callback != nullptr) {
        tox_data->tox->conference_peer_name_callback(tox_data->tox, conference_number, peer_number, name, length,
                tox_data->user_data);
    }
}

static void tox_conference_peer_list_changed_handler(Messenger *m, uint32_t conference_number, void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->conference_peer_list_changed_callback != nullptr) {
        tox_data->tox->conference_peer_list_changed_callback(tox_data->tox, conference_number, tox_data->user_data);
    }
}

static void tox_friend_lossy_packet_handler(Messenger *m, uint32_t friend_number, const uint8_t *data, size_t length,
        void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_lossy_packet_callback != nullptr) {
        tox_data->tox->friend_lossy_packet_callback(tox_data->tox, friend_number, data, length, tox_data->user_data);
    }
}

static void tox_friend_lossless_packet_handler(Messenger *m, uint32_t friend_number, const uint8_t *data, size_t length,
        void *user_data)
{
    struct Tox_Userdata *tox_data = (struct Tox_Userdata *)user_data;

    if (tox_data->tox->friend_lossless_packet_callback != nullptr) {
        tox_data->tox->friend_lossless_packet_callback(tox_data->tox, friend_number, data, length, tox_data->user_data);
    }
}


bool tox_version_is_compatible(uint32_t major, uint32_t minor, uint32_t patch)
{
    return TOX_VERSION_IS_API_COMPATIBLE(major, minor, patch);
}

static State_Load_Status state_load_callback(void *outer, const uint8_t *data, uint32_t length, uint16_t type)
{
    const Tox *tox = (const Tox *)outer;
    State_Load_Status status = STATE_LOAD_STATUS_CONTINUE;

	tox->m->userdata = outer;
    if (messenger_load_state_section(tox->m, data, length, type, &status)
            || conferences_load_state_section(tox->m->conferences_object, data, length, type, &status)) {
        return status;
    }

    if (type == STATE_TYPE_END) {
        if (length != 0) {
            return STATE_LOAD_STATUS_ERROR;
        }

        return STATE_LOAD_STATUS_END;
    }

    LOGGER_ERROR(tox->m->log, "Load state: contains unrecognized part (len %u, type %u)\n",
                 length, type);

    return STATE_LOAD_STATUS_CONTINUE;
}

/* Load tox from data of size length. */
static int tox_load(Tox *tox, const uint8_t *data, uint32_t length)
{
    uint32_t data32[2];
    const uint32_t cookie_len = sizeof(data32);

    if (length < cookie_len) {
        return -1;
    }

    memcpy(data32, data, sizeof(uint32_t));
    lendian_bytes_to_host32(data32 + 1, data + sizeof(uint32_t));

    if (data32[0] != 0 || data32[1] != STATE_COOKIE_GLOBAL) {
        return -1;
    }
    return state_load(tox->m->log, state_load_callback, tox, data + cookie_len,
                      length - cookie_len, STATE_COOKIE_TYPE);
}


Tox *tox_new(const struct Tox_Options *options, Tox_Err_New *error)
{
    Tox *tox = (Tox *)calloc(1, sizeof(Tox));

    if (tox == nullptr) {
        SET_ERROR_PARAMETER(error, TOX_ERR_NEW_MALLOC);
        return nullptr;
    }

    Messenger_Options m_options = {0};

    bool load_savedata_sk = false, load_savedata_tox = false;

    struct Tox_Options *default_options = nullptr;

    if (options == nullptr) {
        Tox_Err_Options_New err;
        default_options = tox_options_new(&err);

        switch (err) {
            case TOX_ERR_OPTIONS_NEW_OK:
                break;

            case TOX_ERR_OPTIONS_NEW_MALLOC:
                SET_ERROR_PARAMETER(error, TOX_ERR_NEW_MALLOC);
                free(tox);
                return nullptr;
        }
    }

    const struct Tox_Options *const opts = options != nullptr ? options : default_options;
    assert(opts != nullptr);

    if (tox_options_get_savedata_type(opts) != TOX_SAVEDATA_TYPE_NONE) {
        if (tox_options_get_savedata_data(opts) == nullptr || tox_options_get_savedata_length(opts) == 0) {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_LOAD_BAD_FORMAT);
            tox_options_free(default_options);
            free(tox);
            return nullptr;
        }
    }

    if (tox_options_get_savedata_type(opts) == TOX_SAVEDATA_TYPE_SECRET_KEY) {
        if (tox_options_get_savedata_length(opts) != TOX_SECRET_KEY_SIZE) {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_LOAD_BAD_FORMAT);
            tox_options_free(default_options);
            free(tox);
            return nullptr;
        }

        load_savedata_sk = true;
    } else if (tox_options_get_savedata_type(opts) == TOX_SAVEDATA_TYPE_TOX_SAVE) {
        if (tox_options_get_savedata_length(opts) < TOX_ENC_SAVE_MAGIC_LENGTH) {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_LOAD_BAD_FORMAT);
            tox_options_free(default_options);
            free(tox);
            return nullptr;
        }

        if (crypto_memcmp(tox_options_get_savedata_data(opts), TOX_ENC_SAVE_MAGIC_NUMBER, TOX_ENC_SAVE_MAGIC_LENGTH) == 0) {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_LOAD_ENCRYPTED);
            tox_options_free(default_options);
            free(tox);
            return nullptr;
        }

        load_savedata_tox = true;
    }

    m_options.ipv6enabled = tox_options_get_ipv6_enabled(opts);
    m_options.udp_disabled = !tox_options_get_udp_enabled(opts);
    m_options.port_range[0] = tox_options_get_start_port(opts);
    m_options.port_range[1] = tox_options_get_end_port(opts);
    m_options.tcp_server_port = tox_options_get_tcp_port(opts);
    m_options.hole_punching_enabled = tox_options_get_hole_punching_enabled(opts);
    m_options.local_discovery_enabled = tox_options_get_local_discovery_enabled(opts);

    m_options.log_callback = (logger_cb *)tox_options_get_log_callback(opts);
	tox->user_add_callback = tox_options_get_user_add_callback(opts);
    m_options.log_context = tox;
    m_options.log_user_data = tox_options_get_log_user_data(opts);
	m_options.device_type = tox_options_get_device_type(opts); 
	m_options.version_code = tox_options_get_version_code(opts);
	m_options.dht_pk = tox_options_get_dht_pk(opts);
	m_options.dht_sk = tox_options_get_dht_sk(opts);

    switch (tox_options_get_proxy_type(opts)) {
        case TOX_PROXY_TYPE_HTTP:
            m_options.proxy_info.proxy_type = TCP_PROXY_HTTP;
            break;

        case TOX_PROXY_TYPE_SOCKS5:
            m_options.proxy_info.proxy_type = TCP_PROXY_SOCKS5;
            break;

        case TOX_PROXY_TYPE_NONE:
            m_options.proxy_info.proxy_type = TCP_PROXY_NONE;
            break;

        default:
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_PROXY_BAD_TYPE);
            tox_options_free(default_options);
            free(tox);
            return nullptr;
    }

    if (m_options.proxy_info.proxy_type != TCP_PROXY_NONE) {
        if (tox_options_get_proxy_port(opts) == 0) {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_PROXY_BAD_PORT);
            tox_options_free(default_options);
            free(tox);
            return nullptr;
        }

        ip_init(&m_options.proxy_info.ip_port.ip, m_options.ipv6enabled);

        if (m_options.ipv6enabled) {
            m_options.proxy_info.ip_port.ip.family = net_family_unspec;
        }

        if (addr_resolve_or_parse_ip(tox_options_get_proxy_host(opts), &m_options.proxy_info.ip_port.ip, nullptr) == 0) {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_PROXY_BAD_HOST);
            // TODO(irungentoo): TOX_ERR_NEW_PROXY_NOT_FOUND if domain.
            tox_options_free(default_options);
            free(tox);
            return nullptr;
        }

        m_options.proxy_info.ip_port.port = net_htons(tox_options_get_proxy_port(opts));
    }

    tox->mono_time = mono_time_new();

	bs_list_init(&tox->timer, sizeof(Event_Node), 2);
	srand((unsigned)time(nullptr)); 

    if (tox->mono_time == nullptr) {
        SET_ERROR_PARAMETER(error, TOX_ERR_NEW_MALLOC);
        tox_options_free(default_options);
        free(tox);
        return nullptr;
    }

    unsigned int m_error;
    Messenger *const m = new_messenger(tox->mono_time, &m_options, &m_error);
    tox->m = m;

    // TODO(iphydf): Clarify this code, check for NULL before new_groupchats, so
    // new_groupchats can assume m is non-NULL.
    if (!new_groupchats(tox->mono_time, m)) {
        kill_messenger(m);

        if (m_error == MESSENGER_ERROR_PORT) {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_PORT_ALLOC);
        } else if (m_error == MESSENGER_ERROR_TCP_SERVER) {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_PORT_ALLOC);
        } else {
            SET_ERROR_PARAMETER(error, TOX_ERR_NEW_MALLOC);
        }

		bs_list_free(&tox->timer);
        mono_time_free(tox->mono_time);
        tox_options_free(default_options);
        free(tox);
        return nullptr;
    }

    m_callback_namechange(m, tox_friend_name_handler);
    m_callback_core_connection(m, tox_self_connection_status_handler);
    m_callback_statusmessage(m, tox_friend_status_message_handler);
    m_callback_userstatus(m, tox_friend_status_handler);
    m_callback_connectionstatus(m, tox_friend_connection_status_handler);
    m_callback_typingchange(m, tox_friend_typing_handler);
    m_callback_read_receipt(m, tox_friend_read_receipt_handler);
    m_callback_friendrequest(m, tox_friend_request_handler);
    m_callback_friendmessage(m, tox_friend_message_handler);
    m_callback_friendmessageoffline(m, tox_friend_message_offline_handler);
    m_callback_groupmessage(m, tox_group_message_handler);
    m_callback_strangermessage(m, tox_stranger_message_handler);
    m_callback_useradd(m, tox_user_add_handler);
    callback_file_control(m, tox_file_recv_control_handler);
    callback_file_reqchunk(m, tox_file_chunk_request_handler);
    callback_file_sendrequest(m, tox_file_recv_handler);
    callback_file_data(m, tox_file_recv_chunk_handler);
    g_callback_group_invite(m->conferences_object, tox_conference_invite_handler);
    g_callback_group_connected(m->conferences_object, tox_conference_connected_handler);
    g_callback_group_message(m->conferences_object, tox_conference_message_handler);
    g_callback_group_title(m->conferences_object, tox_conference_title_handler);
    g_callback_peer_name(m->conferences_object, tox_conference_peer_name_handler);
    g_callback_peer_list_changed(m->conferences_object, tox_conference_peer_list_changed_handler);
    custom_lossy_packet_registerhandler(m, tox_friend_lossy_packet_handler);
    custom_lossless_packet_registerhandler(m, tox_friend_lossless_packet_handler);

    if (load_savedata_tox
            && tox_load(tox, tox_options_get_savedata_data(opts), tox_options_get_savedata_length(opts)) == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_NEW_LOAD_BAD_FORMAT);
    } else if (load_savedata_sk) {
        load_secret_key(m->net_crypto, tox_options_get_savedata_data(opts));
        SET_ERROR_PARAMETER(error, TOX_ERR_NEW_OK);
    } else {
        SET_ERROR_PARAMETER(error, TOX_ERR_NEW_OK);
    }
    tox_options_free(default_options);
    return tox;
}

void tox_kill(Tox *tox)
{
    if (tox == nullptr) {
        return;
    }

    Messenger *m = tox->m;
    LOGGER_ASSERT(m->log, m->msi_packet == nullptr, "Attempted to kill tox while toxav is still alive");
    kill_groupchats(m->conferences_object);
    kill_messenger(m);
    mono_time_free(tox->mono_time);
    free(tox);
}

static uint32_t end_size(void)
{
    return 2 * sizeof(uint32_t);
}

static void end_save(uint8_t *data)
{
    state_write_section_header(data, STATE_COOKIE_TYPE, 0, STATE_TYPE_END);
}

size_t tox_get_savedata_size(const Tox *tox)
{
    const Messenger *m = tox->m;
    return 2 * sizeof(uint32_t)
           + messenger_size(m)
           + conferences_size(m->conferences_object)
           + end_size();
}

void tox_get_savedata(const Tox *tox, uint8_t *savedata)
{
    if (savedata == nullptr) {
        return;
    }

    memset(savedata, 0, tox_get_savedata_size(tox));

    const uint32_t size32 = sizeof(uint32_t);

    // write cookie
    memset(savedata, 0, size32);
    savedata += size32;
    host_to_lendian_bytes32(savedata, STATE_COOKIE_GLOBAL);
    savedata += size32;

    const Messenger *m = tox->m;
    savedata = messenger_save(m, savedata);
    savedata = conferences_save(m->conferences_object, savedata);
    end_save(savedata);
}

bool tox_bootstrap(Tox *tox, const char *host, uint16_t port, const uint8_t *public_key, Tox_Err_Bootstrap *error)
{
    if (!host || !public_key) {
        SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_NULL);
        return 0;
    }

    if (port == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_BAD_PORT);
        return 0;
    }

    IP_Port *root;

    const int32_t count = net_getipport(host, &root, TOX_SOCK_DGRAM);

    if (count == -1) {
        net_freeipport(root);
        SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_BAD_HOST);
        return 0;
    }

    unsigned int i;

    for (i = 0; i < count; ++i) {
        root[i].port = net_htons(port);

        Messenger *m = tox->m;
        onion_add_bs_path_node(m->onion_c, root[i], public_key);
        dht_bootstrap(m->dht, root[i], public_key);
    }

    net_freeipport(root);

    if (count) {
        SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_OK);
        return 1;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_BAD_HOST);
    return 0;
}

bool tox_add_tcp_relay(Tox *tox, const char *host, uint16_t port, const uint8_t *public_key,
                       Tox_Err_Bootstrap *error)
{
    if (!host || !public_key) {
        SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_NULL);
        return 0;
    }

    if (port == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_BAD_PORT);
        return 0;
    }

    IP_Port *root;

    int32_t count = net_getipport(host, &root, TOX_SOCK_STREAM);

    if (count == -1) {
        net_freeipport(root);
        SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_BAD_HOST);
        return 0;
    }

    unsigned int i;

    for (i = 0; i < count; ++i) {
        root[i].port = net_htons(port);

        Messenger *m = tox->m;
        add_tcp_relay(m->net_crypto, root[i], public_key);
    }

    net_freeipport(root);

    if (count) {
        SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_OK);
        return 1;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_BOOTSTRAP_BAD_HOST);
    return 0;
}

Tox_Connection tox_self_get_connection_status(const Tox *tox)
{
    const Messenger *m = tox->m;

    const unsigned int ret = onion_connection_status(m->onion_c);

    if (ret == 2) {
        return TOX_CONNECTION_UDP;
    }

    if (ret == 1) {
        return TOX_CONNECTION_TCP;
    }

    return TOX_CONNECTION_NONE;
}


void tox_callback_self_connection_status(Tox *tox, tox_self_connection_status_cb *callback)
{
    tox->self_connection_status_callback = callback;
}

uint32_t tox_iteration_interval(const Tox *tox)
{
    const Messenger *m = tox->m;
    return messenger_run_interval(m);
}

void tox_iterate(Tox *tox, void *user_data)
{
    mono_time_update(tox->mono_time);

    Messenger *m = tox->m;
    struct Tox_Userdata tox_data = { tox, user_data };
    do_messenger(m, &tox_data);
    do_groupchats(m->conferences_object, &tox_data);
	event_loop(tox, &tox->timer);
}

void tox_self_get_address(const Tox *tox, uint8_t *address)
{
    if (address) {
        const Messenger *m = tox->m;
        getaddress(m, address);
    }
}

void tox_self_set_nospam(Tox *tox, uint32_t nospam)
{
    Messenger *m = tox->m;
    set_nospam(m->fr, net_htonl(nospam));
}

uint32_t tox_self_get_nospam(const Tox *tox)
{
    const Messenger *m = tox->m;
    return net_ntohl(get_nospam(m->fr));
}

void tox_self_get_public_key(const Tox *tox, uint8_t *public_key)
{
    const Messenger *m = tox->m;

    if (public_key) {
        memcpy(public_key, nc_get_self_public_key(m->net_crypto), CRYPTO_PUBLIC_KEY_SIZE);
    }
}

void tox_self_get_secret_key(const Tox *tox, uint8_t *secret_key)
{
    const Messenger *m = tox->m;

    if (secret_key) {
        memcpy(secret_key, nc_get_self_secret_key(m->net_crypto), CRYPTO_SECRET_KEY_SIZE);
    }
}

bool tox_self_set_name(Tox *tox, const uint8_t *name, size_t length, Tox_Err_Set_Info *error)
{
    if (!name && length != 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_SET_INFO_NULL);
        return 0;
    }

    Messenger *m = tox->m;

    if (setname(m, name, length) == 0) {
        // TODO(irungentoo): function to set different per group names?
        send_name_all_groups(m->conferences_object);
        SET_ERROR_PARAMETER(error, TOX_ERR_SET_INFO_OK);
        return 1;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_SET_INFO_TOO_LONG);
    return 0;
}

size_t tox_self_get_name_size(const Tox *tox)
{
    const Messenger *m = tox->m;
    return m_get_self_name_size(m);
}

void tox_self_get_name(const Tox *tox, uint8_t *name)
{
    if (name) {
        const Messenger *m = tox->m;
        getself_name(m, name);
    }
}

bool tox_self_set_status_message(Tox *tox, const uint8_t *status_message, size_t length, Tox_Err_Set_Info *error)
{
    if (!status_message && length != 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_SET_INFO_NULL);
        return 0;
    }

    Messenger *m = tox->m;

    if (m_set_statusmessage(m, status_message, length) == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_SET_INFO_OK);
        return 1;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_SET_INFO_TOO_LONG);
    return 0;
}

size_t tox_self_get_status_message_size(const Tox *tox)
{
    const Messenger *m = tox->m;
    return m_get_self_statusmessage_size(m);
}

void tox_self_get_status_message(const Tox *tox, uint8_t *status_message)
{
    if (status_message) {
        const Messenger *m = tox->m;
        m_copy_self_statusmessage(m, status_message);
    }
}

void tox_self_set_status(Tox *tox, Tox_User_Status status)
{
    Messenger *m = tox->m;
    m_set_userstatus(m, status);
}

Tox_User_Status tox_self_get_status(const Tox *tox)
{
    const Messenger *m = tox->m;
    const uint8_t status = m_get_self_userstatus(m);
    return (Tox_User_Status)status;
}

static void set_friend_error(const Logger *log, int32_t ret, Tox_Err_Friend_Add *error)
{
    switch (ret) {
        case FAERR_TOOLONG:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_TOO_LONG);
            break;

        case FAERR_NOMESSAGE:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_NO_MESSAGE);
            break;

        case FAERR_OWNKEY:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_OWN_KEY);
            break;

        case FAERR_ALREADYSENT:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_ALREADY_SENT);
            break;

        case FAERR_BADCHECKSUM:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_BAD_CHECKSUM);
            break;

        case FAERR_SETNEWNOSPAM:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_SET_NEW_NOSPAM);
            break;

        case FAERR_NOMEM:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_MALLOC);
            break;

        default:
            /* can't happen */
            LOGGER_FATAL(log, "impossible: unknown friend-add error");
            break;
    }
}

uint32_t tox_friend_add(Tox *tox, const uint8_t *address, const uint8_t *message, size_t length,
                        Tox_Err_Friend_Add *error)
{
    if (!address || !message) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_NULL);
        return UINT32_MAX;
    }

    Messenger *m = tox->m;
    const int32_t ret = m_addfriend(m, address, message, length);

    if (ret >= 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_OK);
        return ret;
    }

    set_friend_error(m->log, ret, error);
    return UINT32_MAX;
}

uint32_t tox_friend_add_norequest(Tox *tox, const uint8_t *public_key, Tox_Err_Friend_Add *error)
{
    if (!public_key) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_NULL);
        return UINT32_MAX;
    }

    Messenger *m = tox->m;
    const int32_t ret = m_addfriend_norequest(m, public_key);

    if (ret >= 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_ADD_OK);
        return ret;
    }

    set_friend_error(m->log, ret, error);
    return UINT32_MAX;
}

bool tox_friend_delete(Tox *tox, uint32_t friend_number, Tox_Err_Friend_Delete *error)
{
    Messenger *m = tox->m;
    const int ret = m_delfriend(m, friend_number);

    // TODO(irungentoo): handle if realloc fails?
    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_DELETE_FRIEND_NOT_FOUND);
        return 0;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_DELETE_OK);
    return 1;
}

uint32_t tox_friend_by_public_key(const Tox *tox, const uint8_t *public_key, Tox_Err_Friend_By_Public_Key *error)
{
    if (!public_key) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_BY_PUBLIC_KEY_NULL);
        return UINT32_MAX;
    }

    const Messenger *m = tox->m;
    const int32_t ret = getfriend_id(m, public_key);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_BY_PUBLIC_KEY_NOT_FOUND);
        return UINT32_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_BY_PUBLIC_KEY_OK);
    return ret;
}


bool tox_frined_set_dht_tcp_relay_node(Tox *tox, uint32_t friend_number, const uint8_t *public_key, const uint8_t *tcp_key, const uint8_t *host, uint16_t port, TOX_ERR_FRIEND_SET_DHT_NODE *error)
{

    const Messenger *m = tox->m;

    set_dht_temp_pk(m->fr_c, friend_number, public_key, nullptr);

    IP_Port *root = nullptr;
    const int32_t count = net_getipport(host, &root, TOX_SOCK_DGRAM);
	if (-1 == count) {
		net_freeipport(root);
		SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SET_DHT_NODE_FAIL);
		return 0;
	}

    unsigned int i;

    for (i = 0; i < count; ++i) {
        root[i].port = net_htons(port);
        friend_add_tcp_relay(m->fr_c,friend_number,root[i], tcp_key);
    }
    net_freeipport(root);

    if(0 ==i){

        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SET_DHT_NODE_FAIL);
        return 0;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SET_DHT_NODE_OK);

    return 1;

}


bool tox_friend_get_public_key(const Tox *tox, uint32_t friend_number, uint8_t *public_key,
                               Tox_Err_Friend_Get_Public_Key *error)
{
    if (!public_key) {
        return 0;
    }

    const Messenger *m = tox->m;

    if (get_real_pk(m, friend_number, public_key) == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_GET_PUBLIC_KEY_FRIEND_NOT_FOUND);
        return 0;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_GET_PUBLIC_KEY_OK);
    return 1;
}



bool tox_friend_exists(const Tox *tox, uint32_t friend_number)
{
    const Messenger *m = tox->m;
    return m_friend_exists(m, friend_number);
}

uint64_t tox_friend_get_last_online(const Tox *tox, uint32_t friend_number, Tox_Err_Friend_Get_Last_Online *error)
{
    const Messenger *m = tox->m;
    const uint64_t timestamp = m_get_last_online(m, friend_number);

    if (timestamp == UINT64_MAX) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_GET_LAST_ONLINE_FRIEND_NOT_FOUND);
        return UINT64_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_GET_LAST_ONLINE_OK);
    return timestamp;
}

size_t tox_self_get_friend_list_size(const Tox *tox)
{
    const Messenger *m = tox->m;
    return count_friendlist(m);
}

void tox_self_get_friend_list(const Tox *tox, uint32_t *friend_list)
{
    if (friend_list) {
        const Messenger *m = tox->m;
        // TODO(irungentoo): size parameter?
        copy_friendlist(m, friend_list, tox_self_get_friend_list_size(tox));
    }
}

size_t tox_friend_get_name_size(const Tox *tox, uint32_t friend_number, Tox_Err_Friend_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = m_get_name_size(m, friend_number);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND);
        return SIZE_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_OK);
    return ret;
}

bool tox_friend_get_name(const Tox *tox, uint32_t friend_number, uint8_t *name, Tox_Err_Friend_Query *error)
{
    if (!name) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_NULL);
        return 0;
    }

    const Messenger *m = tox->m;
    const int ret = getname(m, friend_number, name);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND);
        return 0;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_OK);
    return 1;
}

void tox_callback_friend_name(Tox *tox, tox_friend_name_cb *callback)
{
    tox->friend_name_callback = callback;
}

size_t tox_friend_get_status_message_size(const Tox *tox, uint32_t friend_number, Tox_Err_Friend_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = m_get_statusmessage_size(m, friend_number);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND);
        return SIZE_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_OK);
    return ret;
}

bool tox_friend_get_status_message(const Tox *tox, uint32_t friend_number, uint8_t *status_message,
                                   Tox_Err_Friend_Query *error)
{
    if (!status_message) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_NULL);
        return false;
    }

    const Messenger *const m = tox->m;
    const int size = m_get_statusmessage_size(m, friend_number);

    if (size == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND);
        return false;
    }

    const int ret = m_copy_statusmessage(m, friend_number, status_message, size);
    LOGGER_ASSERT(m->log, ret == size, "concurrency problem: friend status message changed");

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_OK);
    return ret == size;
}

void tox_callback_friend_status_message(Tox *tox, tox_friend_status_message_cb *callback)
{
    tox->friend_status_message_callback = callback;
}

Tox_User_Status tox_friend_get_status(const Tox *tox, uint32_t friend_number, Tox_Err_Friend_Query *error)
{
    const Messenger *m = tox->m;

    const int ret = m_get_userstatus(m, friend_number);

    if (ret == USERSTATUS_INVALID) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND);
        return (Tox_User_Status)(TOX_USER_STATUS_BUSY + 1);
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_OK);
    return (Tox_User_Status)ret;
}

void tox_callback_friend_status(Tox *tox, tox_friend_status_cb *callback)
{
    tox->friend_status_callback = callback;
}

Tox_Connection tox_friend_get_connection_status(const Tox *tox, uint32_t friend_number, Tox_Err_Friend_Query *error)
{
    const Messenger *m = tox->m;

    const int ret = m_get_friend_connectionstatus(m, friend_number);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND);
        return TOX_CONNECTION_NONE;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_OK);
    return (Tox_Connection)ret;
}

void tox_callback_friend_connection_status(Tox *tox, tox_friend_connection_status_cb *callback)
{
    tox->friend_connection_status_callback = callback;
}

bool tox_friend_get_typing(const Tox *tox, uint32_t friend_number, Tox_Err_Friend_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = m_get_istyping(m, friend_number);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND);
        return 0;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_QUERY_OK);
    return !!ret;
}

void tox_callback_friend_typing(Tox *tox, tox_friend_typing_cb *callback)
{
    tox->friend_typing_callback = callback;
}

bool tox_self_set_typing(Tox *tox, uint32_t friend_number, bool typing, Tox_Err_Set_Typing *error)
{
    Messenger *m = tox->m;

    if (m_set_usertyping(m, friend_number, typing) == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_SET_TYPING_FRIEND_NOT_FOUND);
        return 0;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_SET_TYPING_OK);
    return 1;
}

static void set_message_error(const Logger *log, int ret, Tox_Err_Friend_Send_Message *error)
{
    switch (ret) {
        case 0:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_OK);
            break;

        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_FRIEND_NOT_FOUND);
            break;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_TOO_LONG);
            break;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_FRIEND_NOT_CONNECTED);
            break;

        case -4:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_SENDQ);
            break;

        case -5:
            LOGGER_FATAL(log, "impossible: Messenger and Tox disagree on message types");
            break;

        default:
            /* can't happen */
            LOGGER_FATAL(log, "impossible: unknown send-message error: %d", ret);
            break;
    }
}

uint32_t tox_friend_send_message(Tox *tox, uint32_t friend_number, Tox_Message_Type type, const uint8_t *message,
                                 size_t length, int64_t local_msg_id, Tox_Err_Friend_Send_Message *error)
{
    if (!message) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_NULL);
        return 0;
    }

    if (!length) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_EMPTY);
        return 0;
    }

    Messenger *m = tox->m;
    uint32_t message_id = 0;
    set_message_error(m->log, m_send_message_generic(m, friend_number, type, message, length, &message_id, local_msg_id), error);
    return message_id;
}

uint32_t tox_friend_send_message_common(Tox *tox, uint32_t friend_number, Tox_Message_Type type, uint8_t cmd, const uint8_t *message,
                                 size_t length, int64_t local_msg_id, uint32_t client_version_code, TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	uint32_t message_id = 0;
	if (!tox->m) {
		return message_id; 
	}
	uint32_t head_len = 0;
	uint8_t magic_number = MAGIC_NUMBER;
	uint32_t extra = 0;
	uint32_t version_code = tox->m->options.version_code;
	if (0 == client_version_code && MAX_VERSION_CODE == version_code) {
		head_len = sizeof(uint8_t);		
	} else {
		head_len = sizeof(uint8_t) + sizeof(uint8_t) + sizeof(uint32_t);
		// packet head: magic number(1 Byte) + cmd(1 Byte) + extra(4 Bytes) 
		// extra: 1~20 bits, version code; 21~24 bits, device type; 25~32 bits, reserve
		// Update by kl 20190/06/19
		if (version_code < MIN_VERSION_CODE || version_code > MAX_VERSION_CODE) {
			return message_id;
		}
		uint32_t device_type = tox->m->options.device_type;
		extra |= version_code;
		extra |= (device_type << 20);
		/*
		 * version_code = extra & 0xfffff
		 * device_type = extra >> 20 & 0xf
		*/
	}
	size_t buf_len = head_len + length;
	uint8_t * buf = (uint8_t *)malloc(buf_len);
	if (buf) {
		memset(buf, 0, buf_len);
		if (0 == client_version_code && MAX_VERSION_CODE == version_code) {
			memcpy(buf, &cmd, sizeof(uint8_t));	
		} else {
			memcpy(buf, &magic_number, sizeof(uint8_t));
			memcpy(buf + sizeof(uint8_t), &cmd, sizeof(uint8_t));
			memcpy(buf + sizeof(uint8_t) * 2, &extra, sizeof(uint32_t));
		}
		memcpy(buf + head_len, message, length);
		message_id = tox_friend_send_message(tox, friend_number, type, buf, buf_len, local_msg_id, error);
		free(buf);
	}
	return message_id;
}

uint32_t tox_friend_send_message_offline(Tox *tox, uint32_t friend_number, TOX_MESSAGE_OFFLINE_CMD cmd, const uint8_t *message,
                                 size_t length, int64_t local_msg_id, TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	return tox_friend_send_message_common(tox, friend_number, TOX_MESSAGE_TYPE_OFFILNE, cmd, message, length, local_msg_id, 0, error);
}

uint32_t tox_friend_send_message_offline_s(Tox *tox, uint32_t friend_number, TOX_MESSAGE_OFFLINE_CMD cmd, const uint8_t *message,
                                 size_t length, int64_t local_msg_id, uint32_t version_code, TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	return tox_friend_send_message_common(tox, friend_number, TOX_MESSAGE_TYPE_OFFILNE, cmd, message, length, local_msg_id,version_code, error);
}

uint32_t tox_group_send_message(Tox *tox, uint32_t friend_number, TOX_MESSAGE_GROUP_CMD cmd, const uint8_t *message,
                                 size_t length, int64_t local_msg_id, TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	return tox_friend_send_message_common(tox, friend_number, TOX_MESSAGE_TYPE_GROUP, cmd, message, length, local_msg_id, 0, error);
}

uint32_t tox_group_send_message_s(Tox *tox, uint32_t friend_number, TOX_MESSAGE_GROUP_CMD cmd, const uint8_t *message,
                                 size_t length, int64_t local_msg_id, uint32_t version_code, TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	return tox_friend_send_message_common(tox, friend_number, TOX_MESSAGE_TYPE_GROUP, cmd, message, length, local_msg_id, version_code, error);
}

uint32_t tox_stranger_send_message(Tox *tox, uint32_t friend_number, TOX_MESSAGE_STRANGER_CMD cmd, const uint8_t *message,
                                 size_t length, int64_t local_msg_id, TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	return tox_friend_send_message_common(tox, friend_number, TOX_MESSAGE_TYPE_STRANGER, cmd, message, length, local_msg_id, 0, error);
}

uint32_t tox_stranger_send_message_s(Tox *tox, uint32_t friend_number, TOX_MESSAGE_STRANGER_CMD cmd, const uint8_t *message,
                                 size_t length, int64_t local_msg_id, uint32_t version_code, TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	return tox_friend_send_message_common(tox, friend_number, TOX_MESSAGE_TYPE_STRANGER, cmd, message, length, local_msg_id, version_code, error);
}

uint32_t tox_encrypt_offline_message(Tox *tox, uint32_t friend_number, const uint8_t *message, size_t length, 
								uint8_t *encrypted_message,  TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	Messenger *m = tox->m;
	int message_len = m_encrypt_offline_message(m, friend_number, message, length, encrypted_message);
	SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_OK);
	return message_len;
}

uint32_t tox_decrypt_offline_message(Tox *tox, uint32_t friend_number, const uint8_t *message, size_t length, 
								uint8_t *decrypted_message, TOX_ERR_FRIEND_SEND_MESSAGE *error) {
	Messenger *m = tox->m;
	int message_len = m_decrypt_offline_message(m, friend_number, message, length, decrypted_message);
	SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SEND_MESSAGE_OK);
	return message_len;
}

void tox_callback_friend_read_receipt(Tox *tox, tox_friend_read_receipt_cb *callback)
{
    tox->friend_read_receipt_callback = callback;
}

void tox_callback_friend_request(Tox *tox, tox_friend_request_cb *callback)
{
    tox->friend_request_callback = callback;
}

void tox_callback_event_timer(Tox *tox, tox_event_timer_cb *callback)
{
	tox->event_timer_callback = callback;
}

void tox_callback_friend_message(Tox *tox, tox_friend_message_cb *callback)
{
    tox->friend_message_callback = callback;
}

void tox_callback_friend_message_offline(Tox *tox, tox_friend_message_offline_cb *callback)
{
    tox->friend_message_offline_callback = callback;
}

void tox_callback_group_message(Tox *tox, tox_group_message_cb *callback) {
    tox->group_message_callback = callback;
}

void tox_callback_stranger_message(Tox *tox, tox_stranger_message_cb *callback) {
    tox->stranger_message_callback = callback;
}

bool tox_hash(uint8_t *hash, const uint8_t *data, size_t length)
{
    if (!hash || (length && !data)) {
        return 0;
    }

    crypto_sha256(hash, data, length);
    return 1;
}

bool tox_file_control(Tox *tox, uint32_t friend_number, uint32_t file_number, Tox_File_Control control,
                      Tox_Err_File_Control *error)
{
    Messenger *m = tox->m;
    const int ret = file_control(m, friend_number, file_number, control);

    if (ret == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_CONTROL_OK);
        return 1;
    }

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_CONTROL_FRIEND_NOT_FOUND);
            return 0;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_CONTROL_FRIEND_NOT_CONNECTED);
            return 0;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_CONTROL_NOT_FOUND);
            return 0;

        case -4:
            /* can't happen */
            return 0;

        case -5:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_CONTROL_ALREADY_PAUSED);
            return 0;

        case -6:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_CONTROL_DENIED);
            return 0;

        case -7:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_CONTROL_NOT_PAUSED);
            return 0;

        case -8:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_CONTROL_SENDQ);
            return 0;
    }

    /* can't happen */
    return 0;
}

bool tox_file_seek(Tox *tox, uint32_t friend_number, uint32_t file_number, uint64_t position,
                   Tox_Err_File_Seek *error)
{
    Messenger *m = tox->m;
    const int ret = file_seek(m, friend_number, file_number, position);

    if (ret == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEEK_OK);
        return 1;
    }

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEEK_FRIEND_NOT_FOUND);
            return 0;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEEK_FRIEND_NOT_CONNECTED);
            return 0;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEEK_NOT_FOUND);
            return 0;

        case -4: // fall-through
        case -5:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEEK_DENIED);
            return 0;

        case -6:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEEK_INVALID_POSITION);
            return 0;

        case -8:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEEK_SENDQ);
            return 0;
    }

    /* can't happen */
    return 0;
}

void tox_callback_file_recv_control(Tox *tox, tox_file_recv_control_cb *callback)
{
    tox->file_recv_control_callback = callback;
}

bool tox_file_get_file_id(const Tox *tox, uint32_t friend_number, uint32_t file_number, uint8_t *file_id,
                          Tox_Err_File_Get *error)
{
    if (!file_id) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_GET_NULL);
        return 0;
    }

    const Messenger *m = tox->m;
    const int ret = file_get_id(m, friend_number, file_number, file_id);

    if (ret == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_GET_OK);
        return 1;
    }

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_GET_FRIEND_NOT_FOUND);
    } else {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_GET_NOT_FOUND);
    }

    return 0;
}

uint32_t tox_file_send(Tox *tox, uint32_t friend_number, uint32_t kind, uint64_t file_size, const uint8_t *file_id,
                       const uint8_t *filename, size_t filename_length, Tox_Err_File_Send *error)
{
    if (filename_length && !filename) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_NULL);
        return UINT32_MAX;
    }

    uint8_t f_id[FILE_ID_LENGTH];

    if (!file_id) {
        /* Tox keys are 32 bytes like FILE_ID_LENGTH. */
        new_symmetric_key(f_id);
        file_id = f_id;
    }

    Messenger *m = tox->m;
    const long int file_num = new_filesender(m, friend_number, kind, file_size, file_id, filename, filename_length);

    if (file_num >= 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_OK);
        return file_num;
    }

    switch (file_num) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_FRIEND_NOT_FOUND);
            return UINT32_MAX;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_NAME_TOO_LONG);
            return UINT32_MAX;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_TOO_MANY);
            return UINT32_MAX;

        case -4:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_FRIEND_NOT_CONNECTED);
            return UINT32_MAX;
    }

    /* can't happen */
    return UINT32_MAX;
}

bool tox_file_send_chunk(Tox *tox, uint32_t friend_number, uint32_t file_number, uint64_t position, const uint8_t *data,
                         size_t length, Tox_Err_File_Send_Chunk *error)
{
    Messenger *m = tox->m;
    const int ret = file_data(m, friend_number, file_number, position, data, length);

    if (ret == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_CHUNK_OK);
        return 1;
    }

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_CHUNK_FRIEND_NOT_FOUND);
            return 0;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_CHUNK_FRIEND_NOT_CONNECTED);
            return 0;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_CHUNK_NOT_FOUND);
            return 0;

        case -4:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_CHUNK_NOT_TRANSFERRING);
            return 0;

        case -5:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_CHUNK_INVALID_LENGTH);
            return 0;

        case -6:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_CHUNK_SENDQ);
            return 0;

        case -7:
            SET_ERROR_PARAMETER(error, TOX_ERR_FILE_SEND_CHUNK_WRONG_POSITION);
            return 0;
    }

    /* can't happen */
    return 0;
}

void tox_callback_file_chunk_request(Tox *tox, tox_file_chunk_request_cb *callback)
{
    tox->file_chunk_request_callback = callback;
}

void tox_callback_file_recv(Tox *tox, tox_file_recv_cb *callback)
{
    tox->file_recv_callback = callback;
}

void tox_callback_file_recv_chunk(Tox *tox, tox_file_recv_chunk_cb *callback)
{
    tox->file_recv_chunk_callback = callback;
}

void tox_callback_conference_invite(Tox *tox, tox_conference_invite_cb *callback)
{
    tox->conference_invite_callback = callback;
}

void tox_callback_conference_connected(Tox *tox, tox_conference_connected_cb *callback)
{
    tox->conference_connected_callback = callback;
}

void tox_callback_conference_message(Tox *tox, tox_conference_message_cb *callback)
{
    tox->conference_message_callback = callback;
}

void tox_callback_conference_title(Tox *tox, tox_conference_title_cb *callback)
{
    tox->conference_title_callback = callback;
}

void tox_callback_conference_peer_name(Tox *tox, tox_conference_peer_name_cb *callback)
{
    tox->conference_peer_name_callback = callback;
}

void tox_callback_conference_peer_list_changed(Tox *tox, tox_conference_peer_list_changed_cb *callback)
{
    tox->conference_peer_list_changed_callback = callback;
}

uint32_t tox_conference_new(Tox *tox, Tox_Err_Conference_New *error)
{
    Messenger *m = tox->m;
    const int ret = add_groupchat(m->conferences_object, GROUPCHAT_TYPE_TEXT);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_NEW_INIT);
        return UINT32_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_NEW_OK);
    return ret;
}

bool tox_conference_delete(Tox *tox, uint32_t conference_number, Tox_Err_Conference_Delete *error)
{
    Messenger *m = tox->m;
    const int ret = del_groupchat(m->conferences_object, conference_number, true);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_DELETE_CONFERENCE_NOT_FOUND);
        return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_DELETE_OK);
    return true;
}

uint32_t tox_conference_peer_count(const Tox *tox, uint32_t conference_number, Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_number_peers(m->conferences_object, conference_number, false);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
        return UINT32_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return ret;
}

size_t tox_conference_peer_get_name_size(const Tox *tox, uint32_t conference_number, uint32_t peer_number,
        Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_peername_size(m->conferences_object, conference_number, peer_number, false);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
            return -1;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_PEER_NOT_FOUND);
            return -1;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return ret;
}

bool tox_conference_peer_get_name(const Tox *tox, uint32_t conference_number, uint32_t peer_number, uint8_t *name,
                                  Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_peername(m->conferences_object, conference_number, peer_number, name, false);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_PEER_NOT_FOUND);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return true;
}

bool tox_conference_peer_get_public_key(const Tox *tox, uint32_t conference_number, uint32_t peer_number,
                                        uint8_t *public_key, Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_peer_pubkey(m->conferences_object, conference_number, peer_number, public_key, false);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_PEER_NOT_FOUND);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return true;
}

bool tox_conference_peer_number_is_ours(const Tox *tox, uint32_t conference_number, uint32_t peer_number,
                                        Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_peernumber_is_ours(m->conferences_object, conference_number, peer_number);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_PEER_NOT_FOUND);
            return false;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_NO_CONNECTION);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return ret;
}

uint32_t tox_conference_offline_peer_count(const Tox *tox, uint32_t conference_number,
        Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_number_peers(m->conferences_object, conference_number, true);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
        return UINT32_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return ret;
}

size_t tox_conference_offline_peer_get_name_size(const Tox *tox, uint32_t conference_number,
        uint32_t offline_peer_number,
        Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_peername_size(m->conferences_object, conference_number, offline_peer_number, true);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
            return -1;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_PEER_NOT_FOUND);
            return -1;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return ret;
}

bool tox_conference_offline_peer_get_name(const Tox *tox, uint32_t conference_number, uint32_t offline_peer_number,
        uint8_t *name,
        Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_peername(m->conferences_object, conference_number, offline_peer_number, name, true);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_PEER_NOT_FOUND);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return true;
}

bool tox_conference_offline_peer_get_public_key(const Tox *tox, uint32_t conference_number,
        uint32_t offline_peer_number,
        uint8_t *public_key, Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    const int ret = group_peer_pubkey(m->conferences_object, conference_number, offline_peer_number, public_key, true);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_PEER_NOT_FOUND);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return true;
}

uint64_t tox_conference_offline_peer_get_last_active(const Tox *tox, uint32_t conference_number,
        uint32_t offline_peer_number,
        Tox_Err_Conference_Peer_Query *error)
{
    const Messenger *m = tox->m;
    uint64_t last_active = UINT64_MAX;
    const int ret = group_frozen_last_active(m->conferences_object, conference_number, offline_peer_number, &last_active);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_CONFERENCE_NOT_FOUND);
            return UINT64_MAX;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_PEER_NOT_FOUND);
            return UINT64_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_PEER_QUERY_OK);
    return last_active;
}

bool tox_conference_invite(Tox *tox, uint32_t friend_number, uint32_t conference_number,
                           Tox_Err_Conference_Invite *error)
{
    Messenger *m = tox->m;
    const int ret = invite_friend(m->conferences_object, friend_number, conference_number);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_INVITE_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_INVITE_FAIL_SEND);
            return false;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_INVITE_NO_CONNECTION);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_INVITE_OK);
    return true;
}

uint32_t tox_conference_join(Tox *tox, uint32_t friend_number, const uint8_t *cookie, size_t length,
                             Tox_Err_Conference_Join *error)
{
    Messenger *m = tox->m;
    const int ret = join_groupchat(m->conferences_object, friend_number, GROUPCHAT_TYPE_TEXT, cookie, length);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_JOIN_INVALID_LENGTH);
            return UINT32_MAX;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_JOIN_WRONG_TYPE);
            return UINT32_MAX;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_JOIN_FRIEND_NOT_FOUND);
            return UINT32_MAX;

        case -4:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_JOIN_DUPLICATE);
            return UINT32_MAX;

        case -5:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_JOIN_INIT_FAIL);
            return UINT32_MAX;

        case -6:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_JOIN_FAIL_SEND);
            return UINT32_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_JOIN_OK);
    return ret;
}

bool tox_conference_send_message(Tox *tox, uint32_t conference_number, Tox_Message_Type type, const uint8_t *message,
                                 size_t length, Tox_Err_Conference_Send_Message *error)
{
    Messenger *m = tox->m;
    int ret = 0;

    if (type == TOX_MESSAGE_TYPE_NORMAL) {
        ret = group_message_send(m->conferences_object, conference_number, message, length);
    } else {
        ret = group_action_send(m->conferences_object, conference_number, message, length);
    }

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_SEND_MESSAGE_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_SEND_MESSAGE_TOO_LONG);
            return false;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_SEND_MESSAGE_NO_CONNECTION);
            return false;

        case -4:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_SEND_MESSAGE_FAIL_SEND);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_SEND_MESSAGE_OK);
    return true;
}

size_t tox_conference_get_title_size(const Tox *tox, uint32_t conference_number, Tox_Err_Conference_Title *error)
{
    const Messenger *m = tox->m;
    const int ret = group_title_get_size(m->conferences_object, conference_number);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_CONFERENCE_NOT_FOUND);
            return -1;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_INVALID_LENGTH);
            return -1;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_OK);
    return ret;
}

bool tox_conference_get_title(const Tox *tox, uint32_t conference_number, uint8_t *title,
                              Tox_Err_Conference_Title *error)
{
    const Messenger *m = tox->m;
    const int ret = group_title_get(m->conferences_object, conference_number, title);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_INVALID_LENGTH);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_OK);
    return true;
}

bool tox_conference_set_title(Tox *tox, uint32_t conference_number, const uint8_t *title, size_t length,
                              Tox_Err_Conference_Title *error)
{
    Messenger *m = tox->m;
    const int ret = group_title_send(m->conferences_object, conference_number, title, length);

    switch (ret) {
        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_CONFERENCE_NOT_FOUND);
            return false;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_INVALID_LENGTH);
            return false;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_FAIL_SEND);
            return false;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_TITLE_OK);
    return true;
}

size_t tox_conference_get_chatlist_size(const Tox *tox)
{
    const Messenger *m = tox->m;
    return count_chatlist(m->conferences_object);
}

void tox_conference_get_chatlist(const Tox *tox, uint32_t *chatlist)
{
    const Messenger *m = tox->m;
    const size_t list_size = tox_conference_get_chatlist_size(tox);
    copy_chatlist(m->conferences_object, chatlist, list_size);
}

Tox_Conference_Type tox_conference_get_type(const Tox *tox, uint32_t conference_number,
        Tox_Err_Conference_Get_Type *error)
{
    const Messenger *m = tox->m;
    const int ret = group_get_type(m->conferences_object, conference_number);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_GET_TYPE_CONFERENCE_NOT_FOUND);
        return (Tox_Conference_Type)ret;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_GET_TYPE_OK);
    return (Tox_Conference_Type)ret;
}

bool tox_conference_get_id(const Tox *tox, uint32_t conference_number, uint8_t *id /* TOX_CONFERENCE_ID_SIZE bytes */)
{
    return conference_get_id(tox->m->conferences_object, conference_number, id);
}

// TODO(iphydf): Delete in 0.3.0.
bool tox_conference_get_uid(const Tox *tox, uint32_t conference_number, uint8_t *uid /* TOX_CONFERENCE_ID_SIZE bytes */)
{
    return tox_conference_get_id(tox, conference_number, uid);
}

uint32_t tox_conference_by_id(const Tox *tox, const uint8_t *id, Tox_Err_Conference_By_Id *error)
{
    if (!id) {
        SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_BY_ID_NULL);
        return UINT32_MAX;
    }

    const int32_t ret = conference_by_id(tox->m->conferences_object, id);

    if (ret == -1) {
        SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_BY_ID_NOT_FOUND);
        return UINT32_MAX;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_BY_ID_OK);
    return ret;
}

// TODO(iphydf): Delete in 0.3.0.
uint32_t tox_conference_by_uid(const Tox *tox, const uint8_t *uid, Tox_Err_Conference_By_Uid *error)
{
    Tox_Err_Conference_By_Id id_error;
    const uint32_t res = tox_conference_by_id(tox, uid, &id_error);

    switch (id_error) {
        case TOX_ERR_CONFERENCE_BY_ID_OK:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_BY_UID_OK);
            break;

        case TOX_ERR_CONFERENCE_BY_ID_NULL:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_BY_UID_NULL);
            break;

        case TOX_ERR_CONFERENCE_BY_ID_NOT_FOUND:
            SET_ERROR_PARAMETER(error, TOX_ERR_CONFERENCE_BY_UID_NOT_FOUND);
            break;
    }

    return res;
}

static void set_custom_packet_error(int ret, Tox_Err_Friend_Custom_Packet *error)
{
    switch (ret) {
        case 0:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_OK);
            break;

        case -1:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_FRIEND_NOT_FOUND);
            break;

        case -2:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_TOO_LONG);
            break;

        case -3:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_INVALID);
            break;

        case -4:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_FRIEND_NOT_CONNECTED);
            break;

        case -5:
            SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_SENDQ);
            break;
    }
}

bool tox_friend_send_lossy_packet(Tox *tox, uint32_t friend_number, const uint8_t *data, size_t length,
                                  Tox_Err_Friend_Custom_Packet *error)
{
    if (!data) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_NULL);
        return 0;
    }

    Messenger *m = tox->m;

    if (length == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_EMPTY);
        return 0;
    }

    // TODO(oxij): this feels ugly, this is needed only because m_send_custom_lossy_packet in Messenger.c
    // sends both AV and custom packets despite its name and this API hides those AV packets
    if (data[0] <= PACKET_ID_RANGE_LOSSY_AV_END) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_INVALID);
        return 0;
    }

    const int ret = m_send_custom_lossy_packet(m, friend_number, data, length);

    set_custom_packet_error(ret, error);

    if (ret == 0) {
        return 1;
    }

    return 0;
}

void tox_callback_friend_lossy_packet(Tox *tox, tox_friend_lossy_packet_cb *callback)
{
    tox->friend_lossy_packet_callback = callback;
}

bool tox_friend_send_lossless_packet(Tox *tox, uint32_t friend_number, const uint8_t *data, size_t length,
                                     Tox_Err_Friend_Custom_Packet *error)
{
    if (!data) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_NULL);
        return 0;
    }

    Messenger *m = tox->m;

    if (length == 0) {
        SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_CUSTOM_PACKET_EMPTY);
        return 0;
    }

    const int ret = send_custom_lossless_packet(m, friend_number, data, length);

    set_custom_packet_error(ret, error);

    if (ret == 0) {
        return 1;
    }

    return 0;
}

void tox_callback_friend_lossless_packet(Tox *tox, tox_friend_lossless_packet_cb *callback)
{
    tox->friend_lossless_packet_callback = callback;
}

void tox_self_get_dht_id(const Tox *tox, uint8_t *dht_id)
{
    if (dht_id) {
        const Messenger *m = tox->m;
        memcpy(dht_id, dht_get_self_public_key(m->dht), CRYPTO_PUBLIC_KEY_SIZE);
    }
}

void tox_self_get_dht_sk(const Tox *tox, uint8_t *dht_sk)
{
    if (dht_sk) {
        const Messenger *m = tox->m;
        memcpy(dht_sk, dht_get_self_secret_key(m->dht), CRYPTO_PUBLIC_KEY_SIZE);
    }
}

uint16_t tox_self_get_udp_port(const Tox *tox, Tox_Err_Get_Port *error)
{
    const Messenger *m = tox->m;
    const uint16_t port = net_htons(net_port(m->net));

    if (port) {
        SET_ERROR_PARAMETER(error, TOX_ERR_GET_PORT_OK);
    } else {
        SET_ERROR_PARAMETER(error, TOX_ERR_GET_PORT_NOT_BOUND);
    }

    return port;
}

uint16_t tox_self_get_tcp_port(const Tox *tox, Tox_Err_Get_Port *error)
{
    const Messenger *m = tox->m;

    if (m->tcp_server) {
        SET_ERROR_PARAMETER(error, TOX_ERR_GET_PORT_OK);
        return m->options.tcp_server_port;
    }

    SET_ERROR_PARAMETER(error, TOX_ERR_GET_PORT_NOT_BOUND);
    return 0;
}

void tox_add_timer_event(Tox *tox, uint32_t event_type, uint32_t friend_number, uint32_t interval, void* user_data, tox_event_timer_cb* cb) {
	add_event(&tox->timer, event_type, friend_number, interval, user_data, cb);				
}

int64_t tox_unixtime() {
	return get_unixtime();
}

int64_t tox_local_msg_id()
{
	return local_msg_id();
}

bool tox_share_id_is_invalid(const uint8_t* share_id)
{
	if (!share_id) {
		return false;
	}	
	long long length = strlen((const char*)share_id);
	int total = 0;
	int last_number = 0;
	for (int i = 0; i < length - 1; ++i) {
		total += (int)share_id[i];	
	}
	last_number = (int)share_id[length - 1] - 48;
	if (last_number != (total % 10)) {
		return false;	
	}
	return true;
}

int tox_is_socket5(const uint8_t *szHost, uint32_t nPort, uint32_t nWaitSeconds)
{
    //LOGGER_INFO(tox->m->log, "IsSocks5 szHost %s nPort %d nWaitSeconds %d  \n",szHost, nPort, nWaitSeconds);
    return IsSocks5((char*)szHost, nPort, nWaitSeconds);
}

int tox_test_node(const uint8_t *szHost, uint16_t nPort, bool bTcp, const uint8_t *szPublicKey, uint32_t nWaitSeconds)
{
//    if(bTcp)
//        LOGGER_INFO(tox->m->log, "TestNode TCP szHost %s nPort %d szPublicKey %s nWaitSeconds %d  \n",szHost, nPort, szPublicKey, nWaitSeconds);
//    else
//        LOGGER_INFO(tox->m->log, "TestNode UDP szHost %s nPort %d szPublicKey %s nWaitSeconds %d  \n",szHost, nPort, szPublicKey, nWaitSeconds);
    
    return TestNode((const char*)szHost, nPort, bTcp, (const char*)szPublicKey, nWaitSeconds);
}

char* tox_get_url(char *szUrlAddress, int nMaxLen, uint64_t mkTime)
{
    return GetUrl(szUrlAddress, nMaxLen, mkTime);
}

bool tox_frined_set_dht_ip_port(Tox *tox, uint32_t friend_number,  const uint8_t *public_key, const uint8_t *host, uint16_t port, int timeout_ms, void *userData)
{
    const Messenger *m = tox->m;
    //set_dht_temp_pk(m->fr_c, friend_number, public_key, nullptr);

    IP_Port *root = nullptr;
    const int32_t count = net_getipport((const char *)host, &root, TOX_SOCK_DGRAM);
    if (-1 == count) {
        net_freeipport(root);
        //SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SET_DHT_NODE_FAIL);
        return 0;
    }
    
    unsigned int i;

    //todo: only one ip
    for (i = 0; i < count; ++i) {
        root[i].port = net_htons(port);
         //dht_ip_callback(m->fr_c, friend_number,root[i]);
    }
    
    if(0 ==i){
        //SET_ERROR_PARAMETER(error, TOX_ERR_FRIEND_SET_DHT_NODE_FAIL);
        return 0;
    }
    set_dht_temp_pk_dire(m->fr_c, friend_number, public_key, root[0]);

    struct Tox_Userdata tox_data = { tox, userData };

    int cnt = 0;
    int intval = 100;
    for(;;) {
        networking_poll(m->net,&tox_data);
        do_net_crypto(m->net_crypto, &tox_data);
        usleep(intval*1000);
        cnt += intval;
        if(timeout_ms < cnt){
            break;
        }
    }

    net_freeipport(root);

    return 1;
}
