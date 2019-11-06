/*
 * Slightly better groupchats implementation.
 */

/*
 * Copyright © 2016-2018 The TokTok team.
 * Copyright © 2014 Tox project.
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

#include "group.h"

#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include "mono_time.h"
#include "state.h"
#include "util.h"

/**
 * Packet type IDs as per the protocol specification.
 */
typedef enum Group_Message_Id {
    GROUP_MESSAGE_PING_ID        = 0,
    GROUP_MESSAGE_NEW_PEER_ID    = 16,
    GROUP_MESSAGE_KILL_PEER_ID   = 17,
    GROUP_MESSAGE_FREEZE_PEER_ID = 18,
    GROUP_MESSAGE_NAME_ID        = 48,
    GROUP_MESSAGE_TITLE_ID       = 49,
} Group_Message_Id;

#define GROUP_MESSAGE_NEW_PEER_LENGTH (sizeof(uint16_t) + CRYPTO_PUBLIC_KEY_SIZE * 2)
#define GROUP_MESSAGE_KILL_PEER_LENGTH (sizeof(uint16_t))

#define MAX_GROUP_MESSAGE_DATA_LEN (MAX_CRYPTO_DATA_SIZE - (1 + MIN_MESSAGE_PACKET_LEN))

typedef enum Invite_Id {
    INVITE_ID             = 0,
    INVITE_RESPONSE_ID    = 1,
} Invite_Id;

#define INVITE_PACKET_SIZE (1 + sizeof(uint16_t) + 1 + GROUP_ID_LENGTH)
#define INVITE_RESPONSE_PACKET_SIZE (1 + sizeof(uint16_t) * 2 + 1 + GROUP_ID_LENGTH)

#define ONLINE_PACKET_DATA_SIZE (sizeof(uint16_t) + 1 + GROUP_ID_LENGTH)

typedef enum Peer_Id {
    PEER_INTRODUCED_ID  = 1,
    PEER_QUERY_ID       = 8,
    PEER_RESPONSE_ID    = 9,
    PEER_TITLE_ID       = 10,
} Peer_Id;

#define MIN_MESSAGE_PACKET_LEN (sizeof(uint16_t) * 2 + sizeof(uint32_t) + 1)

/* return false if the groupnumber is not valid.
 * return true if the groupnumber is valid.
 */
static bool is_groupnumber_valid(const Group_Chats *g_c, uint32_t groupnumber)
{
    if (groupnumber >= g_c->num_chats) {
        return false;
    }

    if (g_c->chats == nullptr) {
        return false;
    }

    if (g_c->chats[groupnumber].status == GROUPCHAT_STATUS_NONE) {
        return false;
    }

    return true;
}


/* Set the size of the groupchat list to num.
 *
 *  return false if realloc fails.
 *  return true if it succeeds.
 */
static bool realloc_conferences(Group_Chats *g_c, uint16_t num)
{
    if (num == 0) {
        free(g_c->chats);
        g_c->chats = nullptr;
        return true;
    }

    Group_c *newgroup_chats = (Group_c *)realloc(g_c->chats, num * sizeof(Group_c));

    if (newgroup_chats == nullptr) {
        return false;
    }

    g_c->chats = newgroup_chats;
    return true;
}

static void setup_conference(Group_c *g)
{
    memset(g, 0, sizeof(Group_c));
}

/* Create a new empty groupchat connection.
 *
 * return -1 on failure.
 * return groupnumber on success.
 */
static int32_t create_group_chat(Group_Chats *g_c)
{
    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        if (g_c->chats[i].status == GROUPCHAT_STATUS_NONE) {
            return i;
        }
    }

    int32_t id = -1;

    if (realloc_conferences(g_c, g_c->num_chats + 1)) {
        id = g_c->num_chats;
        ++g_c->num_chats;
        setup_conference(&g_c->chats[id]);
    }

    return id;
}


/* Wipe a groupchat.
 *
 * return -1 on failure.
 * return 0 on success.
 */
static int wipe_group_chat(Group_Chats *g_c, uint32_t groupnumber)
{
    if (!is_groupnumber_valid(g_c, groupnumber)) {
        return -1;
    }

    uint16_t i;
    crypto_memzero(&g_c->chats[groupnumber], sizeof(Group_c));

    for (i = g_c->num_chats; i != 0; --i) {
        if (g_c->chats[i - 1].status != GROUPCHAT_STATUS_NONE) {
            break;
        }
    }

    if (g_c->num_chats != i) {
        g_c->num_chats = i;
        realloc_conferences(g_c, g_c->num_chats);
    }

    return 0;
}

static Group_c *get_group_c(const Group_Chats *g_c, uint32_t groupnumber)
{
    if (!is_groupnumber_valid(g_c, groupnumber)) {
        return nullptr;
    }

    return &g_c->chats[groupnumber];
}

/*
 * check if peer with real_pk is in peer array.
 *
 * return peer index if peer is in chat.
 * return -1 if peer is not in chat.
 *
 * TODO(irungentoo): make this more efficient.
 */

static int peer_in_chat(const Group_c *chat, const uint8_t *real_pk)
{
    for (uint32_t i = 0; i < chat->numpeers; ++i) {
        if (id_equal(chat->group[i].real_pk, real_pk)) {
            return i;
        }
    }

    return -1;
}

static int frozen_in_chat(const Group_c *chat, const uint8_t *real_pk)
{
    for (uint32_t i = 0; i < chat->numfrozen; ++i) {
        if (id_equal(chat->frozen[i].real_pk, real_pk)) {
            return i;
        }
    }

    return -1;
}

/*
 * check if group with the given type and id is in group array.
 *
 * return group number if peer is in list.
 * return -1 if group is not in list.
 *
 * TODO(irungentoo): make this more efficient and maybe use constant time comparisons?
 */
static int32_t get_group_num(const Group_Chats *g_c, const uint8_t type, const uint8_t *id)
{
    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        if (g_c->chats[i].type == type && crypto_memcmp(g_c->chats[i].id, id, GROUP_ID_LENGTH) == 0) {
            return i;
        }
    }

    return -1;
}

int32_t conference_by_id(const Group_Chats *g_c, const uint8_t *id)
{
    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        if (crypto_memcmp(g_c->chats[i].id, id, GROUP_ID_LENGTH) == 0) {
            return i;
        }
    }

    return -1;
}

/*
 * check if peer with peer_number is in peer array.
 *
 * return peer index if peer is in chat.
 * return -1 if peer is not in chat.
 *
 * TODO(irungentoo): make this more efficient.
 */
static int get_peer_index(const Group_c *g, uint16_t peer_number)
{
    for (uint32_t i = 0; i < g->numpeers; ++i) {
        if (g->group[i].peer_number == peer_number) {
            return i;
        }
    }

    return -1;
}


static uint64_t calculate_comp_value(const uint8_t *pk1, const uint8_t *pk2)
{
    uint64_t cmp1 = 0, cmp2 = 0;

    for (size_t i = 0; i < sizeof(uint64_t); ++i) {
        cmp1 = (cmp1 << 8) + (uint64_t)pk1[i];
        cmp2 = (cmp2 << 8) + (uint64_t)pk2[i];
    }

    return cmp1 - cmp2;
}

typedef enum Groupchat_Closest {
    GROUPCHAT_CLOSEST_NONE,
    GROUPCHAT_CLOSEST_ADDED,
    GROUPCHAT_CLOSEST_REMOVED
} Groupchat_Closest;

static int add_to_closest(Group_Chats *g_c, uint32_t groupnumber, const uint8_t *real_pk, const uint8_t *temp_pk)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if (public_key_cmp(g->real_pk, real_pk) == 0) {
        return -1;
    }

    unsigned int i;
    unsigned int index = DESIRED_CLOSE_CONNECTIONS;

    for (i = 0; i < DESIRED_CLOSE_CONNECTIONS; ++i) {
        if (g->closest_peers[i].entry && public_key_cmp(real_pk, g->closest_peers[i].real_pk) == 0) {
            return 0;
        }
    }

    for (i = 0; i < DESIRED_CLOSE_CONNECTIONS; ++i) {
        if (g->closest_peers[i].entry == 0) {
            index = i;
            break;
        }
    }

    if (index == DESIRED_CLOSE_CONNECTIONS) {
        uint64_t comp_val = calculate_comp_value(g->real_pk, real_pk);
        uint64_t comp_d = 0;

        for (i = 0; i < (DESIRED_CLOSE_CONNECTIONS / 2); ++i) {
            uint64_t comp;
            comp = calculate_comp_value(g->real_pk, g->closest_peers[i].real_pk);

            if (comp > comp_val && comp > comp_d) {
                index = i;
                comp_d = comp;
            }
        }

        comp_val = calculate_comp_value(real_pk, g->real_pk);

        for (i = (DESIRED_CLOSE_CONNECTIONS / 2); i < DESIRED_CLOSE_CONNECTIONS; ++i) {
            uint64_t comp = calculate_comp_value(g->closest_peers[i].real_pk, g->real_pk);

            if (comp > comp_val && comp > comp_d) {
                index = i;
                comp_d = comp;
            }
        }
    }

    if (index == DESIRED_CLOSE_CONNECTIONS) {
        return -1;
    }

    uint8_t old_real_pk[CRYPTO_PUBLIC_KEY_SIZE];
    uint8_t old_temp_pk[CRYPTO_PUBLIC_KEY_SIZE];
    uint8_t old = 0;

    if (g->closest_peers[index].entry) {
        memcpy(old_real_pk, g->closest_peers[index].real_pk, CRYPTO_PUBLIC_KEY_SIZE);
        memcpy(old_temp_pk, g->closest_peers[index].temp_pk, CRYPTO_PUBLIC_KEY_SIZE);
        old = 1;
    }

    g->closest_peers[index].entry = 1;
    memcpy(g->closest_peers[index].real_pk, real_pk, CRYPTO_PUBLIC_KEY_SIZE);
    memcpy(g->closest_peers[index].temp_pk, temp_pk, CRYPTO_PUBLIC_KEY_SIZE);

    if (old) {
        add_to_closest(g_c, groupnumber, old_real_pk, old_temp_pk);
    }

    if (!g->changed) {
        g->changed = GROUPCHAT_CLOSEST_ADDED;
    }

    return 0;
}

static unsigned int pk_in_closest_peers(const Group_c *g, uint8_t *real_pk)
{
    unsigned int i;

    for (i = 0; i < DESIRED_CLOSE_CONNECTIONS; ++i) {
        if (!g->closest_peers[i].entry) {
            continue;
        }

        if (public_key_cmp(g->closest_peers[i].real_pk, real_pk) == 0) {
            return 1;
        }
    }

    return 0;
}

static int add_conn_to_groupchat(Group_Chats *g_c, int friendcon_id, uint32_t groupnumber, uint8_t reason,
                                 uint8_t lock);

static void remove_conn_reason(Group_Chats *g_c, uint32_t groupnumber, uint16_t i, uint8_t reason);

static int send_packet_online(Friend_Connections *fr_c, int friendcon_id, uint16_t group_num, uint8_t type,
                              const uint8_t *id);

static int connect_to_closest(Group_Chats *g_c, uint32_t groupnumber, void *userdata)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if (!g->changed) {
        return 0;
    }

    if (g->changed == GROUPCHAT_CLOSEST_REMOVED) {
        for (uint32_t i = 0; i < g->numpeers; ++i) {
            add_to_closest(g_c, groupnumber, g->group[i].real_pk, g->group[i].temp_pk);
        }
    }

    for (uint32_t i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type == GROUPCHAT_CLOSE_NONE) {
            continue;
        }

        if (!(g->close[i].reasons & GROUPCHAT_CLOSE_REASON_CLOSEST)) {
            continue;
        }

        uint8_t real_pk[CRYPTO_PUBLIC_KEY_SIZE];
        uint8_t dht_temp_pk[CRYPTO_PUBLIC_KEY_SIZE];
        get_friendcon_public_keys(real_pk, dht_temp_pk, g_c->fr_c, g->close[i].number);

        if (!pk_in_closest_peers(g, real_pk)) {
            remove_conn_reason(g_c, groupnumber, i, GROUPCHAT_CLOSE_REASON_CLOSEST);
        }
    }

    for (uint32_t i = 0; i < DESIRED_CLOSE_CONNECTIONS; ++i) {
        if (!g->closest_peers[i].entry) {
            continue;
        }

        int friendcon_id = getfriend_conn_id_pk(g_c->fr_c, g->closest_peers[i].real_pk);

        uint8_t lock = 1;

        if (friendcon_id == -1) {
            friendcon_id = new_friend_connection(g_c->fr_c, g->closest_peers[i].real_pk);
            lock = 0;

            if (friendcon_id == -1) {
                continue;
            }

            set_dht_temp_pk(g_c->fr_c, friendcon_id, g->closest_peers[i].temp_pk, userdata);
        }

        add_conn_to_groupchat(g_c, friendcon_id, groupnumber, GROUPCHAT_CLOSE_REASON_CLOSEST, lock);

        if (friend_con_connected(g_c->fr_c, friendcon_id) == FRIENDCONN_STATUS_CONNECTED) {
            send_packet_online(g_c->fr_c, friendcon_id, groupnumber, g->type, g->id);
        }
    }

    g->changed = GROUPCHAT_CLOSEST_NONE;

    return 0;
}

static int get_frozen_index(const Group_c *g, uint16_t peer_number)
{
    for (uint32_t i = 0; i < g->numfrozen; ++i) {
        if (g->frozen[i].peer_number == peer_number) {
            return i;
        }
    }

    return -1;
}

static bool delete_frozen(Group_c *g, uint32_t frozen_index)
{
    if (frozen_index >= g->numfrozen) {
        return false;
    }

    --g->numfrozen;

    if (g->numfrozen == 0) {
        free(g->frozen);
        g->frozen = nullptr;
    } else {
        if (g->numfrozen != frozen_index) {
            g->frozen[frozen_index] = g->frozen[g->numfrozen];
        }

        Group_Peer *const frozen_temp = (Group_Peer *)realloc(g->frozen, sizeof(Group_Peer) * (g->numfrozen));

        if (frozen_temp == nullptr) {
            return false;
        }

        g->frozen = frozen_temp;
    }

    return true;
}

/* Update last_active timestamp on peer, and thaw the peer if it is frozen.
 *
 * return peer index if peer is in the conference.
 * return -1 otherwise, and on error.
 */
static int note_peer_active(Group_Chats *g_c, uint32_t groupnumber, uint16_t peer_number, void *userdata)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const int peer_index = get_peer_index(g, peer_number);

    if (peer_index != -1) {
        g->group[peer_index].last_active = mono_time_get(g_c->mono_time);
        return peer_index;
    }

    const int frozen_index = get_frozen_index(g, peer_number);

    if (frozen_index == -1) {
        return -1;
    }

    /* Now thaw the peer */

    Group_Peer *temp = (Group_Peer *)realloc(g->group, sizeof(Group_Peer) * (g->numpeers + 1));

    if (temp == nullptr) {
        return -1;
    }

    g->group = temp;
    g->group[g->numpeers] = g->frozen[frozen_index];
    g->group[g->numpeers].temp_pk_updated = false;
    g->group[g->numpeers].last_active = mono_time_get(g_c->mono_time);

    add_to_closest(g_c, groupnumber, g->group[g->numpeers].real_pk, g->group[g->numpeers].temp_pk);

    ++g->numpeers;

    if (!delete_frozen(g, frozen_index)) {
        return -1;
    }

    if (g_c->peer_list_changed_callback) {
        g_c->peer_list_changed_callback(g_c->m, groupnumber, userdata);
    }

    if (g->peer_on_join) {
        g->peer_on_join(g->object, groupnumber, g->numpeers - 1);
    }

    g->need_send_name = true;

    return g->numpeers - 1;
}

static int delpeer(Group_Chats *g_c, uint32_t groupnumber, int peer_index, void *userdata, bool keep_connection);

static void delete_any_peer_with_pk(Group_Chats *g_c, uint32_t groupnumber, const uint8_t *real_pk, void *userdata)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return;
    }

    const int prev_peer_index = peer_in_chat(g, real_pk);

    if (prev_peer_index >= 0) {
        delpeer(g_c, groupnumber, prev_peer_index, userdata, false);
    }

    const int prev_frozen_index = frozen_in_chat(g, real_pk);

    if (prev_frozen_index >= 0) {
        delete_frozen(g, prev_frozen_index);
    }
}

/* Add a peer to the group chat, or update an existing peer.
 *
 * fresh indicates whether we should consider this information on the peer to
 * be current, and so should update temp_pk and consider the peer active.
 *
 * do_gc_callback indicates whether we want to trigger callbacks set by the client
 * via the public API. This should be set to false if this function is called
 * from outside of the tox_iterate() loop.
 *
 * return peer_index if success or peer already in chat.
 * return -1 if error.
 */
static int addpeer(Group_Chats *g_c, uint32_t groupnumber, const uint8_t *real_pk, const uint8_t *temp_pk,
                   uint16_t peer_number, void *userdata, bool fresh, bool do_gc_callback)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const int peer_index = fresh ?
                           note_peer_active(g_c, groupnumber, peer_number, userdata) :
                           get_peer_index(g, peer_number);

    if (peer_index != -1) {
        if (!id_equal(g->group[peer_index].real_pk, real_pk)) {
            return -1;
        }

        if (fresh || !g->group[peer_index].temp_pk_updated) {
            id_copy(g->group[peer_index].temp_pk, temp_pk);
            g->group[peer_index].temp_pk_updated = true;
        }

        return peer_index;
    }

    if (!fresh) {
        const int frozen_index = get_frozen_index(g, peer_number);

        if (frozen_index != -1) {
            if (!id_equal(g->frozen[frozen_index].real_pk, real_pk)) {
                return -1;
            }

            id_copy(g->frozen[frozen_index].temp_pk, temp_pk);

            return -1;
        }
    }

    delete_any_peer_with_pk(g_c, groupnumber, real_pk, userdata);

    Group_Peer *temp = (Group_Peer *)realloc(g->group, sizeof(Group_Peer) * (g->numpeers + 1));

    if (temp == nullptr) {
        return -1;
    }

    memset(&temp[g->numpeers], 0, sizeof(Group_Peer));
    g->group = temp;

    id_copy(g->group[g->numpeers].real_pk, real_pk);
    id_copy(g->group[g->numpeers].temp_pk, temp_pk);
    g->group[g->numpeers].temp_pk_updated = true;
    g->group[g->numpeers].peer_number = peer_number;

    g->group[g->numpeers].last_active = mono_time_get(g_c->mono_time);
    ++g->numpeers;

    add_to_closest(g_c, groupnumber, real_pk, temp_pk);

    if (do_gc_callback && g_c->peer_list_changed_callback) {
        g_c->peer_list_changed_callback(g_c->m, groupnumber, userdata);
    }

    if (g->peer_on_join) {
        g->peer_on_join(g->object, groupnumber, g->numpeers - 1);
    }

    return g->numpeers - 1;
}

static int remove_close_conn(Group_Chats *g_c, uint32_t groupnumber, int friendcon_id)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    uint32_t i;

    for (i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type == GROUPCHAT_CLOSE_NONE) {
            continue;
        }

        if (g->close[i].number == (unsigned int)friendcon_id) {
            g->close[i].type = GROUPCHAT_CLOSE_NONE;
            kill_friend_connection(g_c->fr_c, friendcon_id);
            return 0;
        }
    }

    return -1;
}


static void remove_from_closest(Group_c *g, int peer_index)
{
    for (uint32_t i = 0; i < DESIRED_CLOSE_CONNECTIONS; ++i) {
        if (g->closest_peers[i].entry && id_equal(g->closest_peers[i].real_pk, g->group[peer_index].real_pk)) {
            g->closest_peers[i].entry = 0;
            g->changed = GROUPCHAT_CLOSEST_REMOVED;
            break;
        }
    }
}

/*
 * Delete a peer from the group chat.
 *
 * return 0 if success
 * return -1 if error.
 */
static int delpeer(Group_Chats *g_c, uint32_t groupnumber, int peer_index, void *userdata, bool keep_connection)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    remove_from_closest(g, peer_index);

    const int friendcon_id = getfriend_conn_id_pk(g_c->fr_c, g->group[peer_index].real_pk);

    if (friendcon_id != -1 && !keep_connection) {
        remove_close_conn(g_c, groupnumber, friendcon_id);
    }

    --g->numpeers;

    void *peer_object = g->group[peer_index].object;

    if (g->numpeers == 0) {
        free(g->group);
        g->group = nullptr;
    } else {
        if (g->numpeers != (uint32_t)peer_index) {
            g->group[peer_index] = g->group[g->numpeers];
        }

        Group_Peer *temp = (Group_Peer *)realloc(g->group, sizeof(Group_Peer) * (g->numpeers));

        if (temp == nullptr) {
            return -1;
        }

        g->group = temp;
    }

    if (g_c->peer_list_changed_callback) {
        g_c->peer_list_changed_callback(g_c->m, groupnumber, userdata);
    }

    if (g->peer_on_leave) {
        g->peer_on_leave(g->object, groupnumber, peer_object);
    }

    return 0;
}

static bool try_send_rejoin(Group_Chats *g_c, uint32_t groupnumber, const uint8_t *real_pk);

static int freeze_peer(Group_Chats *g_c, uint32_t groupnumber, int peer_index, void *userdata)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    try_send_rejoin(g_c, groupnumber, g->group[peer_index].real_pk);

    Group_Peer *temp = (Group_Peer *)realloc(g->frozen, sizeof(Group_Peer) * (g->numfrozen + 1));

    if (temp == nullptr) {
        return -1;
    }

    g->frozen = temp;
    g->frozen[g->numfrozen] = g->group[peer_index];
    ++g->numfrozen;

    return delpeer(g_c, groupnumber, peer_index, userdata, true);
}


/* Set the nick for a peer.
 *
 * do_gc_callback indicates whether we want to trigger callbacks set by the client
 * via the public API. This should be set to false if this function is called
 * from outside of the tox_iterate() loop.
 *
 * return 0 on success.
 * return -1 if error.
 */
static int setnick(Group_Chats *g_c, uint32_t groupnumber, int peer_index, const uint8_t *nick, uint16_t nick_len,
                   void *userdata, bool do_gc_callback)
{
    if (nick_len > MAX_NAME_LENGTH) {
        return -1;
    }

    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    g->group[peer_index].nick_updated = true;

    /* same name as already stored? */
    if (g->group[peer_index].nick_len == nick_len) {
        if (nick_len == 0 || !memcmp(g->group[peer_index].nick, nick, nick_len)) {
            return 0;
        }
    }

    if (nick_len) {
        memcpy(g->group[peer_index].nick, nick, nick_len);
    }

    g->group[peer_index].nick_len = nick_len;

    if (do_gc_callback && g_c->peer_name_callback) {
        g_c->peer_name_callback(g_c->m, groupnumber, peer_index, nick, nick_len, userdata);
    }

    return 0;
}

static int settitle(Group_Chats *g_c, uint32_t groupnumber, int peer_index, const uint8_t *title, uint8_t title_len,
                    void *userdata)
{
    if (title_len > MAX_NAME_LENGTH || title_len == 0) {
        return -1;
    }

    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    /* same as already set? */
    if (g->title_len == title_len && !memcmp(g->title, title, title_len)) {
        return 0;
    }

    memcpy(g->title, title, title_len);
    g->title_len = title_len;

    g->title_fresh = true;

    if (g_c->title_callback) {
        g_c->title_callback(g_c->m, groupnumber, peer_index, title, title_len, userdata);
    }

    return 0;
}

/* Check if the group has no online connection, and freeze all peers if so */
static void check_disconnected(Group_Chats *g_c, uint32_t groupnumber, void *userdata)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return;
    }

    for (uint32_t i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type == GROUPCHAT_CLOSE_ONLINE) {
            return;
        }
    }

    for (uint32_t i = 0; i < g->numpeers; ++i) {
        while (i < g->numpeers && !id_equal(g->group[i].real_pk, g->real_pk)) {
            freeze_peer(g_c, groupnumber, i, userdata);
        }
    }
}

static void set_conns_type_close(Group_Chats *g_c, uint32_t groupnumber, int friendcon_id, uint8_t type, void *userdata)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return;
    }

    uint32_t i;

    for (i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type == GROUPCHAT_CLOSE_NONE) {
            continue;
        }

        if (g->close[i].number != (unsigned int)friendcon_id) {
            continue;
        }

        if (type == GROUPCHAT_CLOSE_ONLINE) {
            send_packet_online(g_c->fr_c, friendcon_id, groupnumber, g->type, g->id);
        } else {
            g->close[i].type = type;
            check_disconnected(g_c, groupnumber, userdata);
        }
    }
}
/* Set the type for all close connections with friendcon_id */
static void set_conns_status_groups(Group_Chats *g_c, int friendcon_id, uint8_t type, void *userdata)
{
    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        set_conns_type_close(g_c, i, friendcon_id, type, userdata);
    }
}

static void rejoin_frozen_friend(Group_Chats *g_c, int friendcon_id)
{
    uint8_t real_pk[CRYPTO_PUBLIC_KEY_SIZE];
    get_friendcon_public_keys(real_pk, nullptr, g_c->fr_c, friendcon_id);

    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        Group_c *g = get_group_c(g_c, i);

        if (!g) {
            continue;
        }

        for (uint32_t j = 0; j < g->numfrozen; ++j) {
            if (id_equal(g->frozen[j].real_pk, real_pk)) {
                try_send_rejoin(g_c, i, real_pk);
                break;
            }
        }
    }
}

static int g_handle_any_status(void *object, int friendcon_id, uint8_t status, void *userdata)
{
    Group_Chats *g_c = (Group_Chats *)object;

    if (status) {
        rejoin_frozen_friend(g_c, friendcon_id);
    }

    return 0;
}

static int g_handle_status(void *object, int friendcon_id, uint8_t status, void *userdata)
{
    Group_Chats *g_c = (Group_Chats *)object;

    if (status) { /* Went online */
        set_conns_status_groups(g_c, friendcon_id, GROUPCHAT_CLOSE_ONLINE, userdata);
    } else { /* Went offline */
        set_conns_status_groups(g_c, friendcon_id, GROUPCHAT_CLOSE_CONNECTION, userdata);
        // TODO(irungentoo): remove timedout connections?
    }

    return 0;
}

static int g_handle_packet(void *object, int friendcon_id, const uint8_t *data, uint16_t length, void *userdata);
static int handle_lossy(void *object, int friendcon_id, const uint8_t *data, uint16_t length, void *userdata);

/* Add friend to group chat.
 *
 * return close index on success
 * return -1 on failure.
 */
static int add_conn_to_groupchat(Group_Chats *g_c, int friendcon_id, uint32_t groupnumber, uint8_t reason,
                                 uint8_t lock)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    uint16_t empty = MAX_GROUP_CONNECTIONS;
    uint16_t ind = MAX_GROUP_CONNECTIONS;

    for (uint16_t i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type == GROUPCHAT_CLOSE_NONE) {
            empty = i;
            continue;
        }

        if (g->close[i].number == (uint32_t)friendcon_id) {
            ind = i; /* Already in list. */
            break;
        }
    }

    if (ind == MAX_GROUP_CONNECTIONS && empty != MAX_GROUP_CONNECTIONS) {
        if (lock) {
            friend_connection_lock(g_c->fr_c, friendcon_id);
        }

        g->close[empty].type = GROUPCHAT_CLOSE_CONNECTION;
        g->close[empty].number = friendcon_id;
        g->close[empty].reasons = 0;
        // TODO(irungentoo):
        friend_connection_callbacks(g_c->m->fr_c, friendcon_id, GROUPCHAT_CALLBACK_INDEX, &g_handle_status, &g_handle_packet,
                                    &handle_lossy, g_c, friendcon_id);
        ind = empty;
    }

    if (ind == MAX_GROUP_CONNECTIONS) {
        return -1;
    }

    if (!(g->close[ind].reasons & reason)) {
        g->close[ind].reasons |= reason;

        if (reason == GROUPCHAT_CLOSE_REASON_INTRODUCER) {
            ++g->num_introducer_connections;
        }
    }

    return ind;
}

static unsigned int send_peer_introduced(Group_Chats *g_c, int friendcon_id, uint16_t group_num);

/* Removes reason for keeping connection.
 *
 * Kills connection if this was the last reason.
 */
static void remove_conn_reason(Group_Chats *g_c, uint32_t groupnumber, uint16_t i, uint8_t reason)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return;
    }

    if (!(g->close[i].reasons & reason)) {
        return;
    }

    g->close[i].reasons &= ~reason;

    if (reason == GROUPCHAT_CLOSE_REASON_INTRODUCER) {
        --g->num_introducer_connections;

        if (g->close[i].type == GROUPCHAT_CLOSE_ONLINE) {
            send_peer_introduced(g_c, g->close[i].number, g->close[i].group_number);
        }
    }

    if (g->close[i].reasons == 0) {
        kill_friend_connection(g_c->fr_c, g->close[i].number);
        g->close[i].type = GROUPCHAT_CLOSE_NONE;
    }
}

/* Creates a new groupchat and puts it in the chats array.
 *
 * type is one of GROUPCHAT_TYPE_*
 *
 * return group number on success.
 * return -1 on failure.
 */
int add_groupchat(Group_Chats *g_c, uint8_t type)
{
    const int32_t groupnumber = create_group_chat(g_c);

    if (groupnumber == -1) {
        return -1;
    }

    Group_c *g = &g_c->chats[groupnumber];

    g->status = GROUPCHAT_STATUS_CONNECTED;
    g->type = type;
    new_symmetric_key(g->id);
    g->peer_number = 0; /* Founder is peer 0. */
    memcpy(g->real_pk, nc_get_self_public_key(g_c->m->net_crypto), CRYPTO_PUBLIC_KEY_SIZE);
    const int peer_index = addpeer(g_c, groupnumber, g->real_pk, dht_get_self_public_key(g_c->m->dht), 0, nullptr, true,
                                   false);

    if (peer_index == -1) {
        return -1;
    }

    setnick(g_c, groupnumber, peer_index, g_c->m->name, g_c->m->name_length, nullptr, false);

    return groupnumber;
}

static bool group_leave(const Group_Chats *g_c, uint32_t groupnumber, bool permanent);

/* Delete a groupchat from the chats array, informing the group first as
 * appropriate.
 *
 * return 0 on success.
 * return -1 if groupnumber is invalid.
 */
int del_groupchat(Group_Chats *g_c, uint32_t groupnumber, bool leave_permanently)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    group_leave(g_c, groupnumber, leave_permanently);

    for (uint32_t i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type == GROUPCHAT_CLOSE_NONE) {
            continue;
        }

        g->close[i].type = GROUPCHAT_CLOSE_NONE;
        kill_friend_connection(g_c->fr_c, g->close[i].number);
    }

    for (uint32_t i = 0; i < g->numpeers; ++i) {
        if (g->peer_on_leave) {
            g->peer_on_leave(g->object, groupnumber, g->group[i].object);
        }
    }

    free(g->group);
    free(g->frozen);

    if (g->group_on_delete) {
        g->group_on_delete(g->object, groupnumber);
    }

    return wipe_group_chat(g_c, groupnumber);
}

/* Copy the public key of (frozen, if frozen is true) peernumber who is in
 * groupnumber to pk. pk must be CRYPTO_PUBLIC_KEY_SIZE long.
 *
 * return 0 on success
 * return -1 if groupnumber is invalid.
 * return -2 if peernumber is invalid.
 */
int group_peer_pubkey(const Group_Chats *g_c, uint32_t groupnumber, int peernumber, uint8_t *pk, bool frozen)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const Group_Peer *list = frozen ? g->frozen : g->group;
    const uint32_t num = frozen ? g->numfrozen : g->numpeers;

    if ((uint32_t)peernumber >= num) {
        return -2;
    }

    memcpy(pk, list[peernumber].real_pk, CRYPTO_PUBLIC_KEY_SIZE);
    return 0;
}

/*
 * Return the size of (frozen, if frozen is true) peernumber's name.
 *
 * return -1 if groupnumber is invalid.
 * return -2 if peernumber is invalid.
 */
int group_peername_size(const Group_Chats *g_c, uint32_t groupnumber, int peernumber, bool frozen)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const Group_Peer *list = frozen ? g->frozen : g->group;
    const uint32_t num = frozen ? g->numfrozen : g->numpeers;

    if ((uint32_t)peernumber >= num) {
        return -2;
    }

    if (list[peernumber].nick_len == 0) {
        return 0;
    }

    return list[peernumber].nick_len;
}

/* Copy the name of (frozen, if frozen is true) peernumber who is in
 * groupnumber to name. name must be at least MAX_NAME_LENGTH long.
 *
 * return length of name if success
 * return -1 if groupnumber is invalid.
 * return -2 if peernumber is invalid.
 */
int group_peername(const Group_Chats *g_c, uint32_t groupnumber, int peernumber, uint8_t *name, bool frozen)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const Group_Peer *list = frozen ? g->frozen : g->group;
    const uint32_t num = frozen ? g->numfrozen : g->numpeers;

    if ((uint32_t)peernumber >= num) {
        return -2;
    }

    if (list[peernumber].nick_len == 0) {
        return 0;
    }

    memcpy(name, list[peernumber].nick, list[peernumber].nick_len);
    return list[peernumber].nick_len;
}

/* Copy last active timestamp of frozennumber who is in groupnumber to
 * last_active.
 *
 * return 0 on success.
 * return -1 if groupnumber is invalid.
 * return -2 if frozennumber is invalid.
 */
int group_frozen_last_active(const Group_Chats *g_c, uint32_t groupnumber, int peernumber,
                             uint64_t *last_active)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if ((uint32_t)peernumber >= g->numfrozen) {
        return -2;
    }

    *last_active = g->frozen[peernumber].last_active;
    return 0;
}

/* List all the (frozen, if frozen is true) peers in the group chat.
 *
 * Copies the names of the peers to the name[length][MAX_NAME_LENGTH] array.
 *
 * Copies the lengths of the names to lengths[length]
 *
 * returns the number of peers on success.
 *
 * return -1 on failure.
 */
int group_names(const Group_Chats *g_c, uint32_t groupnumber, uint8_t names[][MAX_NAME_LENGTH], uint16_t lengths[],
                uint16_t length, bool frozen)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const uint32_t num = frozen ? g->numfrozen : g->numpeers;

    unsigned int i;

    for (i = 0; i < num && i < length; ++i) {
        lengths[i] = group_peername(g_c, groupnumber, i, names[i], frozen);
    }

    return i;
}

/* Return the number of (frozen, if frozen is true) peers in the group chat on
 * success.
 * return -1 if groupnumber is invalid.
 */
int group_number_peers(const Group_Chats *g_c, uint32_t groupnumber, bool frozen)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    return frozen ? g->numfrozen : g->numpeers;
}

/* return 1 if the peernumber corresponds to ours.
 * return 0 if the peernumber is not ours.
 * return -1 if groupnumber is invalid.
 * return -2 if peernumber is invalid.
 * return -3 if we are not connected to the group chat.
 */
int group_peernumber_is_ours(const Group_Chats *g_c, uint32_t groupnumber, int peernumber)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if ((uint32_t)peernumber >= g->numpeers) {
        return -2;
    }

    if (g->status != GROUPCHAT_STATUS_CONNECTED) {
        return -3;
    }

    return g->peer_number == g->group[peernumber].peer_number;
}

/* return the type of groupchat (GROUPCHAT_TYPE_) that groupnumber is.
 *
 * return -1 on failure.
 * return type on success.
 */
int group_get_type(const Group_Chats *g_c, uint32_t groupnumber)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    return g->type;
}

/* Copies the unique id of group_chat[groupnumber] into id.
*
* return false on failure.
* return true on success.
*/
bool conference_get_id(const Group_Chats *g_c, uint32_t groupnumber, uint8_t *id)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return false;
    }

    if (id != nullptr) {
        memcpy(id, g->id, sizeof(g->id));
    }

    return true;
}

/* Send a group packet to friendcon_id.
 *
 *  return 1 on success
 *  return 0 on failure
 */
static unsigned int send_packet_group_peer(Friend_Connections *fr_c, int friendcon_id, uint8_t packet_id,
        uint16_t group_num, const uint8_t *data, uint16_t length)
{
    if (1 + sizeof(uint16_t) + length > MAX_CRYPTO_DATA_SIZE) {
        return 0;
    }

    group_num = net_htons(group_num);
    VLA(uint8_t, packet, 1 + sizeof(uint16_t) + length);
    packet[0] = packet_id;
    memcpy(packet + 1, &group_num, sizeof(uint16_t));
    memcpy(packet + 1 + sizeof(uint16_t), data, length);
    return write_cryptpacket(friendconn_net_crypto(fr_c), friend_connection_crypt_connection_id(fr_c, friendcon_id), packet,
                             SIZEOF_VLA(packet), 0) != -1;
}

/* Send a group lossy packet to friendcon_id.
 *
 *  return 1 on success
 *  return 0 on failure
 */
static unsigned int send_lossy_group_peer(Friend_Connections *fr_c, int friendcon_id, uint8_t packet_id,
        uint16_t group_num, const uint8_t *data, uint16_t length)
{
    if (1 + sizeof(uint16_t) + length > MAX_CRYPTO_DATA_SIZE) {
        return 0;
    }

    group_num = net_htons(group_num);
    VLA(uint8_t, packet, 1 + sizeof(uint16_t) + length);
    packet[0] = packet_id;
    memcpy(packet + 1, &group_num, sizeof(uint16_t));
    memcpy(packet + 1 + sizeof(uint16_t), data, length);
    return send_lossy_cryptpacket(friendconn_net_crypto(fr_c), friend_connection_crypt_connection_id(fr_c, friendcon_id),
                                  packet, SIZEOF_VLA(packet)) != -1;
}

/* invite friendnumber to groupnumber.
 *
 * return 0 on success.
 * return -1 if groupnumber is invalid.
 * return -2 if invite packet failed to send.
 * return -3 if we are not connected to the group chat.
 */
int invite_friend(Group_Chats *g_c, uint32_t friendnumber, uint32_t groupnumber)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if (g->status != GROUPCHAT_STATUS_CONNECTED) {
        return -3;
    }

    uint8_t invite[INVITE_PACKET_SIZE];
    invite[0] = INVITE_ID;
    const uint16_t groupchat_num = net_htons((uint16_t)groupnumber);
    memcpy(invite + 1, &groupchat_num, sizeof(groupchat_num));
    invite[1 + sizeof(groupchat_num)] = g->type;
    memcpy(invite + 1 + sizeof(groupchat_num) + 1, g->id, GROUP_ID_LENGTH);

    if (send_conference_invite_packet(g_c->m, friendnumber, invite, sizeof(invite))) {
        return 0;
    }

    return -2;
}

/* Send a rejoin packet to a peer if we have a friend connection to the peer.
 * return true if a packet was sent.
 * return false otherwise.
 */
static bool try_send_rejoin(Group_Chats *g_c, uint32_t groupnumber, const uint8_t *real_pk)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return false;
    }

    const int friendcon_id = getfriend_conn_id_pk(g_c->fr_c, real_pk);

    if (friendcon_id == -1) {
        return false;
    }

    uint8_t packet[1 + 1 + GROUP_ID_LENGTH];
    packet[0] = PACKET_ID_REJOIN_CONFERENCE;
    packet[1] = g->type;
    memcpy(packet + 2, g->id, GROUP_ID_LENGTH);

    if (write_cryptpacket(friendconn_net_crypto(g_c->fr_c), friend_connection_crypt_connection_id(g_c->fr_c, friendcon_id),
                          packet, sizeof(packet), 0) == -1) {
        return false;
    }

    add_conn_to_groupchat(g_c, friendcon_id, groupnumber, GROUPCHAT_CLOSE_REASON_INTRODUCER, 1);

    return true;
}

static unsigned int send_peer_query(Group_Chats *g_c, int friendcon_id, uint16_t group_num);

/* Join a group (you need to have been invited first.)
 *
 * expected_type is the groupchat type we expect the chat we are joining is.
 *
 * return group number on success.
 * return -1 if data length is invalid.
 * return -2 if group is not the expected type.
 * return -3 if friendnumber is invalid.
 * return -4 if client is already in this group.
 * return -5 if group instance failed to initialize.
 * return -6 if join packet fails to send.
 */
int join_groupchat(Group_Chats *g_c, uint32_t friendnumber, uint8_t expected_type, const uint8_t *data, uint16_t length)
{
    if (length != sizeof(uint16_t) + 1 + GROUP_ID_LENGTH) {
        return -1;
    }

    if (data[sizeof(uint16_t)] != expected_type) {
        return -2;
    }

    const int friendcon_id = getfriendcon_id(g_c->m, friendnumber);

    if (friendcon_id == -1) {
        return -3;
    }

    if (get_group_num(g_c, data[sizeof(uint16_t)], data + sizeof(uint16_t) + 1) != -1) {
        return -4;
    }

    const int groupnumber = create_group_chat(g_c);

    if (groupnumber == -1) {
        return -5;
    }

    Group_c *g = &g_c->chats[groupnumber];

    const uint16_t group_num = net_htons(groupnumber);
    g->status = GROUPCHAT_STATUS_VALID;
    memcpy(g->real_pk, nc_get_self_public_key(g_c->m->net_crypto), CRYPTO_PUBLIC_KEY_SIZE);

    uint8_t response[INVITE_RESPONSE_PACKET_SIZE];
    response[0] = INVITE_RESPONSE_ID;
    memcpy(response + 1, &group_num, sizeof(uint16_t));
    memcpy(response + 1 + sizeof(uint16_t), data, sizeof(uint16_t) + 1 + GROUP_ID_LENGTH);

    if (send_conference_invite_packet(g_c->m, friendnumber, response, sizeof(response))) {
        uint16_t other_groupnum;
        memcpy(&other_groupnum, data, sizeof(other_groupnum));
        other_groupnum = net_ntohs(other_groupnum);
        g->type = data[sizeof(uint16_t)];
        memcpy(g->id, data + sizeof(uint16_t) + 1, GROUP_ID_LENGTH);
        const int close_index = add_conn_to_groupchat(g_c, friendcon_id, groupnumber, GROUPCHAT_CLOSE_REASON_INTRODUCER, 1);

        if (close_index != -1) {
            g->close[close_index].group_number = other_groupnum;
            g->close[close_index].type = GROUPCHAT_CLOSE_ONLINE;
        }

        send_peer_query(g_c, friendcon_id, other_groupnum);
        return groupnumber;
    }

    g->status = GROUPCHAT_STATUS_NONE;
    return -6;
}

/* Set handlers for custom lossy packets. */
void group_lossy_packet_registerhandler(Group_Chats *g_c, uint8_t byte, lossy_packet_cb *function)
{
    g_c->lossy_packethandlers[byte].function = function;
}

/* Set the callback for group invites. */
void g_callback_group_invite(Group_Chats *g_c, g_conference_invite_cb *function)
{
    g_c->invite_callback = function;
}

/* Set the callback for group connection. */
void g_callback_group_connected(Group_Chats *g_c, g_conference_connected_cb *function)
{
    g_c->connected_callback = function;
}

/* Set the callback for group messages. */
void g_callback_group_message(Group_Chats *g_c, g_conference_message_cb *function)
{
    g_c->message_callback = function;
}

/* Set callback function for peer nickname changes.
 *
 * It gets called every time a peer changes their nickname.
 */
void g_callback_peer_name(Group_Chats *g_c, peer_name_cb *function)
{
    g_c->peer_name_callback = function;
}

/* Set callback function for peer list changes.
 *
 * It gets called every time the name list changes(new peer, deleted peer)
 */
void g_callback_peer_list_changed(Group_Chats *g_c, peer_list_changed_cb *function)
{
    g_c->peer_list_changed_callback = function;
}

/* Set callback function for title changes. */
void g_callback_group_title(Group_Chats *g_c, title_cb *function)
{
    g_c->title_callback = function;
}

/* Set a function to be called when a new peer joins a group chat.
 *
 * return 0 on success.
 * return -1 on failure.
 */
int callback_groupchat_peer_new(const Group_Chats *g_c, uint32_t groupnumber, peer_on_join_cb *function)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    g->peer_on_join = function;
    return 0;
}

/* Set a function to be called when a peer leaves a group chat.
 *
 * return 0 on success.
 * return -1 on failure.
 */
int callback_groupchat_peer_delete(Group_Chats *g_c, uint32_t groupnumber, peer_on_leave_cb *function)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    g->peer_on_leave = function;
    return 0;
}

/* Set a function to be called when the group chat is deleted.
 *
 * return 0 on success.
 * return -1 on failure.
 */
int callback_groupchat_delete(Group_Chats *g_c, uint32_t groupnumber, group_on_delete_cb *function)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    g->group_on_delete = function;
    return 0;
}

static int send_message_group(const Group_Chats *g_c, uint32_t groupnumber, uint8_t message_id, const uint8_t *data,
                              uint16_t len);

static int group_ping_send(const Group_Chats *g_c, uint32_t groupnumber)
{
    if (send_message_group(g_c, groupnumber, GROUP_MESSAGE_PING_ID, nullptr, 0) > 0) {
        return 0;
    }

    return -1;
}

/* send a new_peer message
 * return 0 on success
 * return -1 on failure
 */
static int group_new_peer_send(const Group_Chats *g_c, uint32_t groupnumber, uint16_t peer_num, const uint8_t *real_pk,
                               uint8_t *temp_pk)
{
    uint8_t packet[GROUP_MESSAGE_NEW_PEER_LENGTH];

    peer_num = net_htons(peer_num);
    memcpy(packet, &peer_num, sizeof(uint16_t));
    memcpy(packet + sizeof(uint16_t), real_pk, CRYPTO_PUBLIC_KEY_SIZE);
    memcpy(packet + sizeof(uint16_t) + CRYPTO_PUBLIC_KEY_SIZE, temp_pk, CRYPTO_PUBLIC_KEY_SIZE);

    if (send_message_group(g_c, groupnumber, GROUP_MESSAGE_NEW_PEER_ID, packet, sizeof(packet)) > 0) {
        return 0;
    }

    return -1;
}

/* send a kill_peer message
 * return true on success
 */
static bool group_kill_peer_send(const Group_Chats *g_c, uint32_t groupnumber, uint16_t peer_num)
{
    uint8_t packet[GROUP_MESSAGE_KILL_PEER_LENGTH];

    peer_num = net_htons(peer_num);
    memcpy(packet, &peer_num, sizeof(uint16_t));

    if (send_message_group(g_c, groupnumber, GROUP_MESSAGE_KILL_PEER_ID, packet, sizeof(packet)) > 0) {
        return true;
    }

    return false;
}

/* send a freeze_peer message
 * return true on success
 */
static bool group_freeze_peer_send(const Group_Chats *g_c, uint32_t groupnumber, uint16_t peer_num)
{
    uint8_t packet[GROUP_MESSAGE_KILL_PEER_LENGTH];

    peer_num = net_htons(peer_num);
    memcpy(packet, &peer_num, sizeof(uint16_t));

    if (send_message_group(g_c, groupnumber, GROUP_MESSAGE_FREEZE_PEER_ID, packet, sizeof(packet)) > 0) {
        return true;
    }

    return false;
}

/* send a name message
 * return 0 on success
 * return -1 on failure
 */
static int group_name_send(const Group_Chats *g_c, uint32_t groupnumber, const uint8_t *nick, uint16_t nick_len)
{
    if (nick_len > MAX_NAME_LENGTH) {
        return -1;
    }

    if (send_message_group(g_c, groupnumber, GROUP_MESSAGE_NAME_ID, nick, nick_len) > 0) {
        return 0;
    }

    return -1;
}

/* send message to announce leaving group
 * return true on success
 */
static bool group_leave(const Group_Chats *g_c, uint32_t groupnumber, bool permanent)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return false;
    }

    if (permanent) {
        return group_kill_peer_send(g_c, groupnumber, g->peer_number);
    } else {
        return group_freeze_peer_send(g_c, groupnumber, g->peer_number);
    }
}


/* set the group's title, limited to MAX_NAME_LENGTH
 * return 0 on success
 * return -1 if groupnumber is invalid.
 * return -2 if title is too long or empty.
 * return -3 if packet fails to send.
 */
int group_title_send(const Group_Chats *g_c, uint32_t groupnumber, const uint8_t *title, uint8_t title_len)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if (title_len > MAX_NAME_LENGTH || title_len == 0) {
        return -2;
    }

    /* same as already set? */
    if (g->title_len == title_len && !memcmp(g->title, title, title_len)) {
        return 0;
    }

    memcpy(g->title, title, title_len);
    g->title_len = title_len;

    if (g->numpeers == 1) {
        return 0;
    }

    if (send_message_group(g_c, groupnumber, GROUP_MESSAGE_TITLE_ID, title, title_len) > 0) {
        return 0;
    }

    return -3;
}

/* return the group's title size.
 * return -1 of groupnumber is invalid.
 * return -2 if title is too long or empty.
 */
int group_title_get_size(const Group_Chats *g_c, uint32_t groupnumber)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if (g->title_len == 0 || g->title_len > MAX_NAME_LENGTH) {
        return -2;
    }

    return g->title_len;
}

/* Get group title from groupnumber and put it in title.
 * Title needs to be a valid memory location with a size of at least MAX_NAME_LENGTH (128) bytes.
 *
 * return length of copied title if success.
 * return -1 if groupnumber is invalid.
 * return -2 if title is too long or empty.
 */
int group_title_get(const Group_Chats *g_c, uint32_t groupnumber, uint8_t *title)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if (g->title_len == 0 || g->title_len > MAX_NAME_LENGTH) {
        return -2;
    }

    memcpy(title, g->title, g->title_len);
    return g->title_len;
}

static bool get_peer_number(const Group_c *g, const uint8_t *real_pk, uint16_t *peer_number)
{
    const int peer_index = peer_in_chat(g, real_pk);

    if (peer_index >= 0) {
        *peer_number = g->group[peer_index].peer_number;
        return true;
    }

    const int frozen_index = frozen_in_chat(g, real_pk);

    if (frozen_index >= 0) {
        *peer_number = g->frozen[frozen_index].peer_number;
        return true;
    }

    return false;
}

static void handle_friend_invite_packet(Messenger *m, uint32_t friendnumber, const uint8_t *data, uint16_t length,
                                        void *userdata)
{
    Group_Chats *g_c = m->conferences_object;

    if (length <= 1) {
        return;
    }

    const uint8_t *invite_data = data + 1;
    const uint16_t invite_length = length - 1;

    switch (data[0]) {
        case INVITE_ID: {
            if (length != INVITE_PACKET_SIZE) {
                return;
            }

            const int groupnumber = get_group_num(g_c, data[1 + sizeof(uint16_t)], data + 1 + sizeof(uint16_t) + 1);

            if (groupnumber == -1) {
                if (g_c->invite_callback) {
                    g_c->invite_callback(m, friendnumber, invite_data[sizeof(uint16_t)], invite_data, invite_length, userdata);
                }

                return;
            }

            break;
        }

        case INVITE_RESPONSE_ID: {
            if (length != INVITE_RESPONSE_PACKET_SIZE) {
                return;
            }

            uint16_t other_groupnum, groupnum;
            memcpy(&groupnum, data + 1 + sizeof(uint16_t), sizeof(uint16_t));
            groupnum = net_ntohs(groupnum);

            Group_c *g = get_group_c(g_c, groupnum);

            if (!g) {
                return;
            }

            if (data[1 + sizeof(uint16_t) * 2] != g->type) {
                return;
            }

            if (crypto_memcmp(data + 1 + sizeof(uint16_t) * 2 + 1, g->id, GROUP_ID_LENGTH) != 0) {
                return;
            }

            /* TODO(irungentoo): what if two people enter the group at the same time and
               are given the same peer_number by different nodes? */
            uint16_t peer_number = random_u16();

            unsigned int tries = 0;

            while (get_peer_index(g, peer_number) != -1 || get_frozen_index(g, peer_number) != -1) {
                peer_number = random_u16();
                ++tries;

                if (tries > 32) {
                    return;
                }
            }

            memcpy(&other_groupnum, data + 1, sizeof(uint16_t));
            other_groupnum = net_ntohs(other_groupnum);

            const int friendcon_id = getfriendcon_id(m, friendnumber);

            if (friendcon_id == -1) {
                // TODO(iphydf): Log something?
                return;
            }

            uint8_t real_pk[CRYPTO_PUBLIC_KEY_SIZE], temp_pk[CRYPTO_PUBLIC_KEY_SIZE];
            get_friendcon_public_keys(real_pk, temp_pk, g_c->fr_c, friendcon_id);

            addpeer(g_c, groupnum, real_pk, temp_pk, peer_number, userdata, true, true);
            const int close_index = add_conn_to_groupchat(g_c, friendcon_id, groupnum, GROUPCHAT_CLOSE_REASON_INTRODUCING, 1);

            if (close_index != -1) {
                g->close[close_index].group_number = other_groupnum;
                g->close[close_index].type = GROUPCHAT_CLOSE_ONLINE;
            }

            group_new_peer_send(g_c, groupnum, peer_number, real_pk, temp_pk);
            break;
        }


        default:
            return;
    }
}

/* Find index of friend in the close list;
 *
 * returns index on success
 * returns -1 on failure.
 */
static int friend_in_close(const Group_c *g, int friendcon_id)
{
    unsigned int i;

    for (i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type == GROUPCHAT_CLOSE_NONE) {
            continue;
        }

        if (g->close[i].number != (uint32_t)friendcon_id) {
            continue;
        }

        return i;
    }

    return -1;
}

/* return number of connected close connections.
 */
static unsigned int count_close_connected(const Group_c *g)
{
    unsigned int i, count = 0;

    for (i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type == GROUPCHAT_CLOSE_ONLINE) {
            ++count;
        }
    }

    return count;
}

static int send_packet_online(Friend_Connections *fr_c, int friendcon_id, uint16_t group_num, uint8_t type,
                              const uint8_t *id)
{
    uint8_t packet[1 + ONLINE_PACKET_DATA_SIZE];
    group_num = net_htons(group_num);
    packet[0] = PACKET_ID_ONLINE_PACKET;
    memcpy(packet + 1, &group_num, sizeof(uint16_t));
    packet[1 + sizeof(uint16_t)] = type;
    memcpy(packet + 1 + sizeof(uint16_t) + 1, id, GROUP_ID_LENGTH);
    return write_cryptpacket(friendconn_net_crypto(fr_c), friend_connection_crypt_connection_id(fr_c, friendcon_id), packet,
                             sizeof(packet), 0) != -1;
}

static int ping_groupchat(Group_Chats *g_c, uint32_t groupnumber);

static int handle_packet_online(Group_Chats *g_c, int friendcon_id, const uint8_t *data, uint16_t length)
{
    if (length != ONLINE_PACKET_DATA_SIZE) {
        return -1;
    }

    const int groupnumber = get_group_num(g_c, data[sizeof(uint16_t)], data + sizeof(uint16_t) + 1);

    if (groupnumber == -1) {
        return -1;
    }

    uint16_t other_groupnum;
    memcpy(&other_groupnum, data, sizeof(uint16_t));
    other_groupnum = net_ntohs(other_groupnum);

    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const int index = friend_in_close(g, friendcon_id);

    if (index == -1) {
        return -1;
    }

    if (g->close[index].type == GROUPCHAT_CLOSE_ONLINE) {
        return -1;
    }

    if (count_close_connected(g) == 0 || (g->close[index].reasons & GROUPCHAT_CLOSE_REASON_INTRODUCER)) {
        send_peer_query(g_c, friendcon_id, other_groupnum);
    }

    g->close[index].group_number = other_groupnum;
    g->close[index].type = GROUPCHAT_CLOSE_ONLINE;
    send_packet_online(g_c->fr_c, friendcon_id, groupnumber, g->type, g->id);

    if (g->close[index].reasons & GROUPCHAT_CLOSE_REASON_INTRODUCING) {
        uint8_t real_pk[CRYPTO_PUBLIC_KEY_SIZE], temp_pk[CRYPTO_PUBLIC_KEY_SIZE];
        get_friendcon_public_keys(real_pk, temp_pk, g_c->fr_c, friendcon_id);

        const int peer_index = peer_in_chat(g, real_pk);

        if (peer_index != -1) {
            group_new_peer_send(g_c, groupnumber, g->group[peer_index].peer_number, real_pk, temp_pk);
        }

        g->need_send_name = true;
    }

    ping_groupchat(g_c, groupnumber);

    return 0;
}

static int handle_packet_rejoin(Group_Chats *g_c, int friendcon_id, const uint8_t *data, uint16_t length,
                                void *userdata)
{
    if (length < 1 + GROUP_ID_LENGTH) {
        return -1;
    }

    const int32_t groupnum = get_group_num(g_c, *data, data + 1);

    const Group_c *g = get_group_c(g_c, groupnum);

    if (!g) {
        return -1;
    }

    uint8_t real_pk[CRYPTO_PUBLIC_KEY_SIZE], temp_pk[CRYPTO_PUBLIC_KEY_SIZE];
    get_friendcon_public_keys(real_pk, temp_pk, g_c->fr_c, friendcon_id);

    uint16_t peer_number;

    if (!get_peer_number(g, real_pk, &peer_number)) {
        return -1;
    }

    addpeer(g_c, groupnum, real_pk, temp_pk, peer_number, userdata, true, true);
    const int close_index = add_conn_to_groupchat(g_c, friendcon_id, groupnum, GROUPCHAT_CLOSE_REASON_INTRODUCING, 1);

    if (close_index != -1) {
        send_packet_online(g_c->fr_c, friendcon_id, groupnum, g->type, g->id);
    }

    return 0;
}


// we could send title with invite, but then if it changes between sending and accepting inv, joinee won't see it

/* return 1 on success.
 * return 0 on failure
 */
static unsigned int send_peer_introduced(Group_Chats *g_c, int friendcon_id, uint16_t group_num)
{
    uint8_t packet[1];
    packet[0] = PEER_INTRODUCED_ID;
    return send_packet_group_peer(g_c->fr_c, friendcon_id, PACKET_ID_DIRECT_CONFERENCE, group_num, packet, sizeof(packet));
}


/* return 1 on success.
 * return 0 on failure
 */
static unsigned int send_peer_query(Group_Chats *g_c, int friendcon_id, uint16_t group_num)
{
    uint8_t packet[1];
    packet[0] = PEER_QUERY_ID;
    return send_packet_group_peer(g_c->fr_c, friendcon_id, PACKET_ID_DIRECT_CONFERENCE, group_num, packet, sizeof(packet));
}

/* return number of peers sent on success.
 * return 0 on failure.
 */
static unsigned int send_peers(Group_Chats *g_c, uint32_t groupnumber, int friendcon_id, uint16_t group_num)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return 0;
    }

    uint8_t response_packet[MAX_CRYPTO_DATA_SIZE - (1 + sizeof(uint16_t))];
    response_packet[0] = PEER_RESPONSE_ID;
    uint8_t *p = response_packet + 1;

    uint16_t sent = 0;
    uint32_t i;

    for (i = 0; i < g->numpeers; ++i) {
        if ((p - response_packet) + sizeof(uint16_t) + CRYPTO_PUBLIC_KEY_SIZE * 2 + 1 + g->group[i].nick_len > sizeof(
                    response_packet)) {
            if (send_packet_group_peer(g_c->fr_c, friendcon_id, PACKET_ID_DIRECT_CONFERENCE, group_num, response_packet,
                                       (p - response_packet))) {
                sent = i;
            } else {
                return sent;
            }

            p = response_packet + 1;
        }

        const uint16_t peer_num = net_htons(g->group[i].peer_number);
        memcpy(p, &peer_num, sizeof(peer_num));
        p += sizeof(peer_num);
        memcpy(p, g->group[i].real_pk, CRYPTO_PUBLIC_KEY_SIZE);
        p += CRYPTO_PUBLIC_KEY_SIZE;
        memcpy(p, g->group[i].temp_pk, CRYPTO_PUBLIC_KEY_SIZE);
        p += CRYPTO_PUBLIC_KEY_SIZE;
        *p = g->group[i].nick_len;
        p += 1;
        memcpy(p, g->group[i].nick, g->group[i].nick_len);
        p += g->group[i].nick_len;
    }

    if (sent != i) {
        if (send_packet_group_peer(g_c->fr_c, friendcon_id, PACKET_ID_DIRECT_CONFERENCE, group_num, response_packet,
                                   (p - response_packet))) {
            sent = i;
        }
    }

    if (g->title_len) {
        VLA(uint8_t, title_packet, 1 + g->title_len);
        title_packet[0] = PEER_TITLE_ID;
        memcpy(title_packet + 1, g->title, g->title_len);
        send_packet_group_peer(g_c->fr_c, friendcon_id, PACKET_ID_DIRECT_CONFERENCE, group_num, title_packet,
                               SIZEOF_VLA(title_packet));
    }

    return sent;
}

static int handle_send_peers(Group_Chats *g_c, uint32_t groupnumber, const uint8_t *data, uint16_t length,
                             void *userdata)
{
    if (length == 0) {
        return -1;
    }

    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const uint8_t *d = data;

    while ((unsigned int)(length - (d - data)) >= sizeof(uint16_t) + CRYPTO_PUBLIC_KEY_SIZE * 2 + 1) {
        uint16_t peer_num;
        memcpy(&peer_num, d, sizeof(peer_num));
        peer_num = net_ntohs(peer_num);
        d += sizeof(uint16_t);

        if (g->status == GROUPCHAT_STATUS_VALID
                && public_key_cmp(d, nc_get_self_public_key(g_c->m->net_crypto)) == 0) {
            g->peer_number = peer_num;
            g->status = GROUPCHAT_STATUS_CONNECTED;

            if (g_c->connected_callback) {
                g_c->connected_callback(g_c->m, groupnumber, userdata);
            }

            g->need_send_name = true;
        }

        const int peer_index = addpeer(g_c, groupnumber, d, d + CRYPTO_PUBLIC_KEY_SIZE, peer_num, userdata, false, true);

        if (peer_index == -1) {
            return -1;
        }

        d += CRYPTO_PUBLIC_KEY_SIZE * 2;
        const uint8_t name_length = *d;
        d += 1;

        if (name_length > (length - (d - data)) || name_length > MAX_NAME_LENGTH) {
            return -1;
        }

        if (!g->group[peer_index].nick_updated) {
            setnick(g_c, groupnumber, peer_index, d, name_length, userdata, true);
        }

        d += name_length;
    }

    return 0;
}

static void handle_direct_packet(Group_Chats *g_c, uint32_t groupnumber, const uint8_t *data, uint16_t length,
                                 int close_index, void *userdata)
{
    if (length == 0) {
        return;
    }

    switch (data[0]) {
        case PEER_INTRODUCED_ID: {
            const Group_c *g = get_group_c(g_c, groupnumber);

            if (!g) {
                return;
            }

            remove_conn_reason(g_c, groupnumber, close_index, GROUPCHAT_CLOSE_REASON_INTRODUCING);
        }

        break;

        case PEER_QUERY_ID: {
            const Group_c *g = get_group_c(g_c, groupnumber);

            if (!g) {
                return;
            }

            if (g->close[close_index].type != GROUPCHAT_CLOSE_ONLINE) {
                return;
            }

            send_peers(g_c, groupnumber, g->close[close_index].number, g->close[close_index].group_number);
        }

        break;

        case PEER_RESPONSE_ID: {
            handle_send_peers(g_c, groupnumber, data + 1, length - 1, userdata);
        }

        break;

        case PEER_TITLE_ID: {
            const Group_c *g = get_group_c(g_c, groupnumber);

            if (!g) {
                break;
            }

            if (!g->title_fresh) {
                settitle(g_c, groupnumber, -1, data + 1, length - 1, userdata);
            }
        }

        break;
    }
}

/* Send message to all close except receiver (if receiver isn't -1)
 * NOTE: this function appends the group chat number to the data passed to it.
 *
 * return number of messages sent.
 */
static unsigned int send_message_all_close(const Group_Chats *g_c, uint32_t groupnumber, const uint8_t *data,
        uint16_t length, int receiver)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return 0;
    }

    uint16_t i, sent = 0;

    for (i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type != GROUPCHAT_CLOSE_ONLINE) {
            continue;
        }

        if ((int)i == receiver) {
            continue;
        }

        if (send_packet_group_peer(g_c->fr_c, g->close[i].number, PACKET_ID_MESSAGE_CONFERENCE, g->close[i].group_number, data,
                                   length)) {
            ++sent;
        }
    }

    return sent;
}

/* Send lossy message to all close except receiver (if receiver isn't -1)
 * NOTE: this function appends the group chat number to the data passed to it.
 *
 * return number of messages sent.
 */
static unsigned int send_lossy_all_close(const Group_Chats *g_c, uint32_t groupnumber, const uint8_t *data,
        uint16_t length,
        int receiver)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return 0;
    }

    unsigned int i, sent = 0, num_connected_closest = 0, connected_closest[DESIRED_CLOSE_CONNECTIONS];

    for (i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
        if (g->close[i].type != GROUPCHAT_CLOSE_ONLINE) {
            continue;
        }

        if ((int)i == receiver) {
            continue;
        }

        if (g->close[i].reasons & GROUPCHAT_CLOSE_REASON_CLOSEST) {
            connected_closest[num_connected_closest] = i;
            ++num_connected_closest;
            continue;
        }

        if (send_lossy_group_peer(g_c->fr_c, g->close[i].number, PACKET_ID_LOSSY_CONFERENCE, g->close[i].group_number, data,
                                  length)) {
            ++sent;
        }
    }

    if (!num_connected_closest) {
        return sent;
    }

    unsigned int to_send = 0;
    uint64_t comp_val_old = ~0;

    for (i = 0; i < num_connected_closest; ++i) {
        uint8_t real_pk[CRYPTO_PUBLIC_KEY_SIZE] = {0};
        uint8_t dht_temp_pk[CRYPTO_PUBLIC_KEY_SIZE] = {0};
        get_friendcon_public_keys(real_pk, dht_temp_pk, g_c->fr_c, g->close[connected_closest[i]].number);
        const uint64_t comp_val = calculate_comp_value(g->real_pk, real_pk);

        if (comp_val < comp_val_old) {
            to_send = connected_closest[i];
            comp_val_old = comp_val;
        }
    }

    if (send_lossy_group_peer(g_c->fr_c, g->close[to_send].number, PACKET_ID_LOSSY_CONFERENCE,
                              g->close[to_send].group_number, data, length)) {
        ++sent;
    }

    unsigned int to_send_other = 0;
    comp_val_old = ~0;

    for (i = 0; i < num_connected_closest; ++i) {
        uint8_t real_pk[CRYPTO_PUBLIC_KEY_SIZE] = {0};
        uint8_t dht_temp_pk[CRYPTO_PUBLIC_KEY_SIZE] = {0};
        get_friendcon_public_keys(real_pk, dht_temp_pk, g_c->fr_c, g->close[connected_closest[i]].number);
        const uint64_t comp_val = calculate_comp_value(real_pk, g->real_pk);

        if (comp_val < comp_val_old) {
            to_send_other = connected_closest[i];
            comp_val_old = comp_val;
        }
    }

    if (to_send_other == to_send) {
        return sent;
    }

    if (send_lossy_group_peer(g_c->fr_c, g->close[to_send_other].number, PACKET_ID_LOSSY_CONFERENCE,
                              g->close[to_send_other].group_number, data, length)) {
        ++sent;
    }

    return sent;
}

/* Send data of len with message_id to groupnumber.
 *
 * return number of peers it was sent to on success.
 * return -1 if groupnumber is invalid.
 * return -2 if message is too long.
 * return -3 if we are not connected to the group.
 * return -4 if message failed to send.
 */
static int send_message_group(const Group_Chats *g_c, uint32_t groupnumber, uint8_t message_id, const uint8_t *data,
                              uint16_t len)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if (len > MAX_GROUP_MESSAGE_DATA_LEN) {
        return -2;
    }

    if (g->status != GROUPCHAT_STATUS_CONNECTED || count_close_connected(g) == 0) {
        return -3;
    }

    VLA(uint8_t, packet, sizeof(uint16_t) + sizeof(uint32_t) + 1 + len);
    const uint16_t peer_num = net_htons(g->peer_number);
    memcpy(packet, &peer_num, sizeof(peer_num));

    ++g->message_number;

    if (!g->message_number) {
        ++g->message_number;
    }

    const uint32_t message_num = net_htonl(g->message_number);
    memcpy(packet + sizeof(uint16_t), &message_num, sizeof(message_num));

    packet[sizeof(uint16_t) + sizeof(uint32_t)] = message_id;

    if (len) {
        memcpy(packet + sizeof(uint16_t) + sizeof(uint32_t) + 1, data, len);
    }

    unsigned int ret = send_message_all_close(g_c, groupnumber, packet, SIZEOF_VLA(packet), -1);

    return (ret == 0) ? -4 : ret;
}

/* send a group message
 * return 0 on success
 * see: send_message_group() for error codes.
 */
int group_message_send(const Group_Chats *g_c, uint32_t groupnumber, const uint8_t *message, uint16_t length)
{
    const int ret = send_message_group(g_c, groupnumber, PACKET_ID_MESSAGE, message, length);

    if (ret > 0) {
        return 0;
    }

    return ret;
}

/* send a group action
 * return 0 on success
 * see: send_message_group() for error codes.
 */
int group_action_send(const Group_Chats *g_c, uint32_t groupnumber, const uint8_t *action, uint16_t length)
{
    const int ret = send_message_group(g_c, groupnumber, PACKET_ID_ACTION, action, length);

    if (ret > 0) {
        return 0;
    }

    return ret;
}

/* High level function to send custom lossy packets.
 *
 * return -1 on failure.
 * return 0 on success.
 */
int send_group_lossy_packet(const Group_Chats *g_c, uint32_t groupnumber, const uint8_t *data, uint16_t length)
{
    // TODO(irungentoo): length check here?
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    VLA(uint8_t, packet, sizeof(uint16_t) * 2 + length);
    const uint16_t peer_number = net_htons(g->peer_number);
    memcpy(packet, &peer_number, sizeof(uint16_t));
    const uint16_t message_num = net_htons(g->lossy_message_number);
    memcpy(packet + sizeof(uint16_t), &message_num, sizeof(uint16_t));
    memcpy(packet + sizeof(uint16_t) * 2, data, length);

    if (send_lossy_all_close(g_c, groupnumber, packet, SIZEOF_VLA(packet), -1) == 0) {
        return -1;
    }

    ++g->lossy_message_number;
    return 0;
}

static Message_Info *find_message_slot_or_reject(uint32_t message_number, uint8_t message_id, Group_Peer *peer)
{
    const bool ignore_older = (message_id == GROUP_MESSAGE_NAME_ID || message_id == GROUP_MESSAGE_TITLE_ID);

    Message_Info *i;

    for (i = peer->last_message_infos; i < peer->last_message_infos + peer->num_last_message_infos; ++i) {
        if (message_number > i->message_number) {
            break;
        }

        if (message_number == i->message_number) {
            return nullptr;
        }

        if (ignore_older && message_id == i->message_id) {
            return nullptr;
        }
    }

    return i;
}

/* Stores message info in peer->last_message_infos.
 *
 * return true if message should be processed;
 * return false otherwise.
 */
static bool check_message_info(uint32_t message_number, uint8_t message_id, Group_Peer *peer)
{
    Message_Info *const i = find_message_slot_or_reject(message_number, message_id, peer);

    if (i == nullptr) {
        return false;
    }

    if (i == peer->last_message_infos + MAX_LAST_MESSAGE_INFOS) {
        return false;
    }

    if (peer->num_last_message_infos < MAX_LAST_MESSAGE_INFOS) {
        ++peer->num_last_message_infos;
    }

    memmove(i + 1, i, ((peer->last_message_infos + peer->num_last_message_infos - 1) - i) * sizeof(Message_Info));

    i->message_number = message_number;
    i->message_id = message_id;

    return true;
}

static void handle_message_packet_group(Group_Chats *g_c, uint32_t groupnumber, const uint8_t *data, uint16_t length,
                                        int close_index, void *userdata)
{
    if (length < sizeof(uint16_t) + sizeof(uint32_t) + 1) {
        return;
    }

    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return;
    }

    uint16_t peer_number;
    memcpy(&peer_number, data, sizeof(uint16_t));
    peer_number = net_ntohs(peer_number);

    uint32_t message_number;
    memcpy(&message_number, data + sizeof(uint16_t), sizeof(message_number));
    message_number = net_ntohl(message_number);

    const uint8_t message_id = data[sizeof(uint16_t) + sizeof(message_number)];
    const uint8_t *msg_data = data + sizeof(uint16_t) + sizeof(message_number) + 1;
    const uint16_t msg_data_len = length - (sizeof(uint16_t) + sizeof(message_number) + 1);

    const bool ignore_frozen = message_id == GROUP_MESSAGE_FREEZE_PEER_ID;

    const int index = ignore_frozen ? get_peer_index(g, peer_number)
                      : note_peer_active(g_c, groupnumber, peer_number, userdata);

    if (index == -1) {
        if (ignore_frozen) {
            return;
        }

        if (g->close[close_index].type != GROUPCHAT_CLOSE_ONLINE) {
            return;
        }

        /* If we don't know the peer this packet came from, then we query the
         * list of peers from the relaying peer.
         * (They would not have relayed it if they didn't know the peer.) */
        send_peer_query(g_c, g->close[close_index].number, g->close[close_index].group_number);
        return;
    }

    if (g->num_introducer_connections > 0 && count_close_connected(g) > DESIRED_CLOSE_CONNECTIONS) {
        for (uint32_t i = 0; i < MAX_GROUP_CONNECTIONS; ++i) {
            if (g->close[i].type == GROUPCHAT_CLOSE_NONE
                    || !(g->close[i].reasons & GROUPCHAT_CLOSE_REASON_INTRODUCER)
                    || i == close_index) {
                continue;
            }

            uint8_t real_pk[CRYPTO_PUBLIC_KEY_SIZE];
            get_friendcon_public_keys(real_pk, nullptr, g_c->fr_c, g->close[i].number);

            if (id_equal(g->group[index].real_pk, real_pk)) {
                /* Received message from peer relayed via another peer, so
                 * the introduction was successful */
                remove_conn_reason(g_c, groupnumber, i, GROUPCHAT_CLOSE_REASON_INTRODUCER);
            }
        }
    }

    if (!check_message_info(message_number, message_id, &g->group[index])) {
        return;
    }

    switch (message_id) {
        case GROUP_MESSAGE_PING_ID:
            break;

        case GROUP_MESSAGE_NEW_PEER_ID: {
            if (msg_data_len != GROUP_MESSAGE_NEW_PEER_LENGTH) {
                return;
            }

            uint16_t new_peer_number;
            memcpy(&new_peer_number, msg_data, sizeof(uint16_t));
            new_peer_number = net_ntohs(new_peer_number);
            addpeer(g_c, groupnumber, msg_data + sizeof(uint16_t), msg_data + sizeof(uint16_t) + CRYPTO_PUBLIC_KEY_SIZE,
                    new_peer_number, userdata, true, true);
        }
        break;

        case GROUP_MESSAGE_KILL_PEER_ID:
        case GROUP_MESSAGE_FREEZE_PEER_ID: {
            if (msg_data_len != GROUP_MESSAGE_KILL_PEER_LENGTH) {
                return;
            }

            uint16_t kill_peer_number;
            memcpy(&kill_peer_number, msg_data, sizeof(uint16_t));
            kill_peer_number = net_ntohs(kill_peer_number);

            if (peer_number == kill_peer_number) {
                if (message_id == GROUP_MESSAGE_KILL_PEER_ID) {
                    delpeer(g_c, groupnumber, index, userdata, false);
                } else {
                    freeze_peer(g_c, groupnumber, index, userdata);
                }
            } else {
                return;
                // TODO(irungentoo):
            }
        }
        break;

        case GROUP_MESSAGE_NAME_ID: {
            if (setnick(g_c, groupnumber, index, msg_data, msg_data_len, userdata, true) == -1) {
                return;
            }
        }
        break;

        case GROUP_MESSAGE_TITLE_ID: {
            if (settitle(g_c, groupnumber, index, msg_data, msg_data_len, userdata) == -1) {
                return;
            }
        }
        break;

        case PACKET_ID_MESSAGE: {
            if (msg_data_len == 0) {
                return;
            }

            VLA(uint8_t, newmsg, msg_data_len + 1);
            memcpy(newmsg, msg_data, msg_data_len);
            newmsg[msg_data_len] = 0;

            // TODO(irungentoo):
            if (g_c->message_callback) {
                g_c->message_callback(g_c->m, groupnumber, index, 0, newmsg, msg_data_len, userdata);
            }

            break;
        }

        case PACKET_ID_ACTION: {
            if (msg_data_len == 0) {
                return;
            }

            VLA(uint8_t, newmsg, msg_data_len + 1);
            memcpy(newmsg, msg_data, msg_data_len);
            newmsg[msg_data_len] = 0;

            // TODO(irungentoo):
            if (g_c->message_callback) {
                g_c->message_callback(g_c->m, groupnumber, index, 1, newmsg, msg_data_len, userdata);
            }

            break;
        }

        default:
            return;
    }

    send_message_all_close(g_c, groupnumber, data, length, -1/* TODO(irungentoo) close_index */);
}

static int g_handle_packet(void *object, int friendcon_id, const uint8_t *data, uint16_t length, void *userdata)
{
    Group_Chats *g_c = (Group_Chats *)object;

    if (length < 1 + sizeof(uint16_t) + 1) {
        return -1;
    }

    if (data[0] == PACKET_ID_ONLINE_PACKET) {
        return handle_packet_online(g_c, friendcon_id, data + 1, length - 1);
    }

    if (data[0] == PACKET_ID_REJOIN_CONFERENCE) {
        return handle_packet_rejoin(g_c, friendcon_id, data + 1, length - 1, userdata);
    }

    if (data[0] != PACKET_ID_DIRECT_CONFERENCE && data[0] != PACKET_ID_MESSAGE_CONFERENCE) {
        return -1;
    }

    uint16_t groupnumber;
    memcpy(&groupnumber, data + 1, sizeof(uint16_t));
    groupnumber = net_ntohs(groupnumber);
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const int index = friend_in_close(g, friendcon_id);

    if (index == -1) {
        return -1;
    }

    switch (data[0]) {
        case PACKET_ID_DIRECT_CONFERENCE: {
            handle_direct_packet(g_c, groupnumber, data + 1 + sizeof(uint16_t), length - (1 + sizeof(uint16_t)), index, userdata);
            break;
        }

        case PACKET_ID_MESSAGE_CONFERENCE: {
            handle_message_packet_group(g_c, groupnumber, data + 1 + sizeof(uint16_t), length - (1 + sizeof(uint16_t)), index,
                                        userdata);
            break;
        }

        default: {
            return 0;
        }
    }

    return 0;
}

/* Did we already receive the lossy packet or not.
 *
 * return -1 on failure.
 * return 0 if packet was not received.
 * return 1 if packet was received.
 *
 * TODO(irungentoo): test this
 */
static unsigned int lossy_packet_not_received(const Group_c *g, int peer_index, uint16_t message_number)
{
    if (peer_index == -1) {
        // TODO(sudden6): invalid return value
        return -1;
    }

    if (g->group[peer_index].bottom_lossy_number == g->group[peer_index].top_lossy_number) {
        g->group[peer_index].top_lossy_number = message_number;
        g->group[peer_index].bottom_lossy_number = (message_number - MAX_LOSSY_COUNT) + 1;
        g->group[peer_index].recv_lossy[message_number % MAX_LOSSY_COUNT] = 1;
        return 0;
    }

    if ((uint16_t)(message_number - g->group[peer_index].bottom_lossy_number) < MAX_LOSSY_COUNT) {
        if (g->group[peer_index].recv_lossy[message_number % MAX_LOSSY_COUNT]) {
            return 1;
        }

        g->group[peer_index].recv_lossy[message_number % MAX_LOSSY_COUNT] = 1;
        return 0;
    }

    if ((uint16_t)(message_number - g->group[peer_index].bottom_lossy_number) > (1 << 15)) {
        // TODO(sudden6): invalid return value
        return -1;
    }

    const uint16_t top_distance = message_number - g->group[peer_index].top_lossy_number;

    if (top_distance >= MAX_LOSSY_COUNT) {
        crypto_memzero(g->group[peer_index].recv_lossy, sizeof(g->group[peer_index].recv_lossy));
        g->group[peer_index].top_lossy_number = message_number;
        g->group[peer_index].bottom_lossy_number = (message_number - MAX_LOSSY_COUNT) + 1;
        g->group[peer_index].recv_lossy[message_number % MAX_LOSSY_COUNT] = 1;
    } else {  // top_distance < MAX_LOSSY_COUNT
        for (unsigned int i = g->group[peer_index].bottom_lossy_number;
                i != g->group[peer_index].bottom_lossy_number + top_distance;
                ++i) {
            g->group[peer_index].recv_lossy[i % MAX_LOSSY_COUNT] = 0;
        }

        g->group[peer_index].top_lossy_number = message_number;
        g->group[peer_index].bottom_lossy_number = (message_number - MAX_LOSSY_COUNT) + 1;
        g->group[peer_index].recv_lossy[message_number % MAX_LOSSY_COUNT] = 1;
    }

    return 0;

}

static int handle_lossy(void *object, int friendcon_id, const uint8_t *data, uint16_t length, void *userdata)
{
    Group_Chats *g_c = (Group_Chats *)object;

    if (length < 1 + sizeof(uint16_t) * 3 + 1) {
        return -1;
    }

    if (data[0] != PACKET_ID_LOSSY_CONFERENCE) {
        return -1;
    }

    uint16_t groupnumber, peer_number, message_number;
    memcpy(&groupnumber, data + 1, sizeof(uint16_t));
    memcpy(&peer_number, data + 1 + sizeof(uint16_t), sizeof(uint16_t));
    memcpy(&message_number, data + 1 + sizeof(uint16_t) * 2, sizeof(uint16_t));
    groupnumber = net_ntohs(groupnumber);
    peer_number = net_ntohs(peer_number);
    message_number = net_ntohs(message_number);

    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    const int index = friend_in_close(g, friendcon_id);

    if (index == -1) {
        return -1;
    }

    if (peer_number == g->peer_number) {
        return -1;
    }

    const int peer_index = get_peer_index(g, peer_number);

    if (peer_index == -1) {
        return -1;
    }

    if (lossy_packet_not_received(g, peer_index, message_number)) {
        return -1;
    }

    const uint8_t *lossy_data = data + 1 + sizeof(uint16_t) * 3;
    uint16_t lossy_length = length - (1 + sizeof(uint16_t) * 3);
    const uint8_t message_id = lossy_data[0];
    ++lossy_data;
    --lossy_length;

    if (g_c->lossy_packethandlers[message_id].function) {
        if (g_c->lossy_packethandlers[message_id].function(g->object, groupnumber, peer_index, g->group[peer_index].object,
                lossy_data, lossy_length) == -1) {
            return -1;
        }
    } else {
        return -1;
    }

    send_lossy_all_close(g_c, groupnumber, data + 1 + sizeof(uint16_t), length - (1 + sizeof(uint16_t)), index);
    return 0;
}

/* Set the object that is tied to the group chat.
 *
 * return 0 on success.
 * return -1 on failure
 */
int group_set_object(const Group_Chats *g_c, uint32_t groupnumber, void *object)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    g->object = object;
    return 0;
}

/* Set the object that is tied to the group peer.
 *
 * return 0 on success.
 * return -1 on failure
 */
int group_peer_set_object(const Group_Chats *g_c, uint32_t groupnumber, int peernumber, void *object)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if ((uint32_t)peernumber >= g->numpeers) {
        return -1;
    }

    g->group[peernumber].object = object;
    return 0;
}

/* Return the object tide to the group chat previously set by group_set_object.
 *
 * return NULL on failure.
 * return object on success.
 */
void *group_get_object(const Group_Chats *g_c, uint32_t groupnumber)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return nullptr;
    }

    return g->object;
}

/* Return the object tide to the group chat peer previously set by group_peer_set_object.
 *
 * return NULL on failure.
 * return object on success.
 */
void *group_peer_get_object(const Group_Chats *g_c, uint32_t groupnumber, int peernumber)
{
    const Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return nullptr;
    }

    if ((uint32_t)peernumber >= g->numpeers) {
        return nullptr;
    }

    return g->group[peernumber].object;
}

/* Interval in seconds to send ping messages */
#define GROUP_PING_INTERVAL 20

static int ping_groupchat(Group_Chats *g_c, uint32_t groupnumber)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    if (mono_time_is_timeout(g_c->mono_time, g->last_sent_ping, GROUP_PING_INTERVAL)) {
        if (group_ping_send(g_c, groupnumber) != -1) { /* Ping */
            g->last_sent_ping = mono_time_get(g_c->mono_time);
        }
    }

    return 0;
}

static int groupchat_freeze_timedout(Group_Chats *g_c, uint32_t groupnumber, void *userdata)
{
    Group_c *g = get_group_c(g_c, groupnumber);

    if (!g) {
        return -1;
    }

    for (uint32_t i = 0; i < g->numpeers; ++i) {
        if (g->group[i].peer_number == g->peer_number) {
            continue;
        }

        if (mono_time_is_timeout(g_c->mono_time, g->group[i].last_active, GROUP_PING_INTERVAL * 3)) {
            freeze_peer(g_c, groupnumber, i, userdata);
        }
    }

    if (g->numpeers <= 1) {
        g->title_fresh = false;
    }

    return 0;
}

/* Send current name (set in messenger) to all online groups.
 */
void send_name_all_groups(Group_Chats *g_c)
{
    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        Group_c *g = get_group_c(g_c, i);

        if (!g) {
            continue;
        }

        if (g->status == GROUPCHAT_STATUS_CONNECTED) {
            group_name_send(g_c, i, g_c->m->name, g_c->m->name_length);
            g->need_send_name = false;
        }
    }
}

#define SAVED_PEER_SIZE_CONSTANT (2 * CRYPTO_PUBLIC_KEY_SIZE + sizeof(uint16_t) + sizeof(uint64_t) + 1)

static uint32_t saved_peer_size(const Group_Peer *peer)
{
    return SAVED_PEER_SIZE_CONSTANT + peer->nick_len;
}

static uint8_t *save_peer(const Group_Peer *peer, uint8_t *data)
{
    memcpy(data, peer->real_pk, CRYPTO_PUBLIC_KEY_SIZE);
    data += CRYPTO_PUBLIC_KEY_SIZE;

    memcpy(data, peer->temp_pk, CRYPTO_PUBLIC_KEY_SIZE);
    data += CRYPTO_PUBLIC_KEY_SIZE;

    host_to_lendian_bytes16(data, peer->peer_number);
    data += sizeof(uint16_t);

    host_to_lendian_bytes64(data, peer->last_active);
    data += sizeof(uint64_t);

    *data = peer->nick_len;
    ++data;

    memcpy(data, peer->nick, peer->nick_len);
    data += peer->nick_len;

    return data;
}

#define SAVED_CONF_SIZE_CONSTANT (1 + GROUP_ID_LENGTH + sizeof(uint32_t) \
      + sizeof(uint16_t) + sizeof(uint16_t) + sizeof(uint32_t) + 1)

static uint32_t saved_conf_size(const Group_c *g)
{
    uint32_t len = SAVED_CONF_SIZE_CONSTANT + g->title_len;

    for (uint32_t j = 0; j < g->numpeers + g->numfrozen; ++j) {
        const Group_Peer *peer = (j < g->numpeers) ? &g->group[j] : &g->frozen[j - g->numpeers];

        if (id_equal(peer->real_pk, g->real_pk)) {
            continue;
        }

        len += saved_peer_size(peer);
    }

    return len;
}

static uint8_t *save_conf(const Group_c *g, uint8_t *data)
{
    *data = g->type;
    ++data;

    memcpy(data, g->id, GROUP_ID_LENGTH);
    data += GROUP_ID_LENGTH;

    host_to_lendian_bytes32(data, g->message_number);
    data += sizeof(uint32_t);

    host_to_lendian_bytes16(data, g->lossy_message_number);
    data += sizeof(uint16_t);

    host_to_lendian_bytes16(data, g->peer_number);
    data += sizeof(uint16_t);

    uint8_t *const numsaved_location = data;
    data += sizeof(uint32_t);

    *data = g->title_len;
    ++data;

    memcpy(data, g->title, g->title_len);
    data += g->title_len;

    uint32_t numsaved = 0;

    for (uint32_t j = 0; j < g->numpeers + g->numfrozen; ++j) {
        const Group_Peer *peer = (j < g->numpeers) ? &g->group[j] : &g->frozen[j - g->numpeers];

        if (id_equal(peer->real_pk, g->real_pk)) {
            continue;
        }

        data = save_peer(peer, data);
        ++numsaved;
    }

    host_to_lendian_bytes32(numsaved_location, numsaved);

    return data;
}

static uint32_t conferences_section_size(const Group_Chats *g_c)
{
    uint32_t len = 0;

    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        const Group_c *g = get_group_c(g_c, i);

        if (!g || g->status != GROUPCHAT_STATUS_CONNECTED) {
            continue;
        }

        len += saved_conf_size(g);
    }

    return len;
}

uint32_t conferences_size(const Group_Chats *g_c)
{
    return 2 * sizeof(uint32_t) + conferences_section_size(g_c);
}

uint8_t *conferences_save(const Group_Chats *g_c, uint8_t *data)
{
    const uint32_t len = conferences_section_size(g_c);
    data = state_write_section_header(data, STATE_COOKIE_TYPE, len, STATE_TYPE_CONFERENCES);

    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        const Group_c *g = get_group_c(g_c, i);

        if (!g || g->status != GROUPCHAT_STATUS_CONNECTED) {
            continue;
        }

        data = save_conf(g, data);
    }

    return data;
}

static State_Load_Status load_conferences(Group_Chats *g_c, const uint8_t *data, uint32_t length)
{
    const uint8_t *init_data = data;

    while (length >= (uint32_t)(data - init_data) + SAVED_CONF_SIZE_CONSTANT) {
        const int groupnumber = create_group_chat(g_c);

        if (groupnumber == -1) {
            return STATE_LOAD_STATUS_ERROR;
        }

        Group_c *g = &g_c->chats[groupnumber];

        g->type = *data;
        ++data;

        memcpy(g->id, data, GROUP_ID_LENGTH);
        data += GROUP_ID_LENGTH;

        lendian_bytes_to_host32(&g->message_number, data);
        data += sizeof(uint32_t);

        lendian_bytes_to_host16(&g->lossy_message_number, data);
        data += sizeof(uint16_t);

        lendian_bytes_to_host16(&g->peer_number, data);
        data += sizeof(uint16_t);

        lendian_bytes_to_host32(&g->numfrozen, data);
        data += sizeof(uint32_t);

        g->frozen = (Group_Peer *)malloc(sizeof(Group_Peer) * g->numfrozen);

        if (g->frozen == nullptr) {
            return STATE_LOAD_STATUS_ERROR;
        }

        g->title_len = *data;
        ++data;

        if (length < (uint32_t)(data - init_data) + g->title_len) {
            return STATE_LOAD_STATUS_ERROR;
        }

        memcpy(g->title, data, g->title_len);
        data += g->title_len;

        for (uint32_t j = 0; j < g->numfrozen; ++j) {
            if (length < (uint32_t)(data - init_data) + SAVED_PEER_SIZE_CONSTANT) {
                return STATE_LOAD_STATUS_ERROR;
            }

            Group_Peer *peer = &g->frozen[j];
            memset(peer, 0, sizeof(Group_Peer));

            id_copy(peer->real_pk, data);
            data += CRYPTO_PUBLIC_KEY_SIZE;
            id_copy(peer->temp_pk, data);
            data += CRYPTO_PUBLIC_KEY_SIZE;

            lendian_bytes_to_host16(&peer->peer_number, data);
            data += sizeof(uint16_t);

            lendian_bytes_to_host64(&peer->last_active, data);
            data += sizeof(uint64_t);

            peer->nick_len = *data;
            ++data;

            if (length < (uint32_t)(data - init_data) + peer->nick_len) {
                return STATE_LOAD_STATUS_ERROR;
            }

            memcpy(peer->nick, data, peer->nick_len);
            data += peer->nick_len;
        }

        g->status = GROUPCHAT_STATUS_CONNECTED;
        memcpy(g->real_pk, nc_get_self_public_key(g_c->m->net_crypto), CRYPTO_PUBLIC_KEY_SIZE);
        const int peer_index = addpeer(g_c, groupnumber, g->real_pk, dht_get_self_public_key(g_c->m->dht), g->peer_number,
                                       nullptr, true, false);

        if (peer_index == -1) {
            return STATE_LOAD_STATUS_ERROR;
        }

        setnick(g_c, groupnumber, peer_index, g_c->m->name, g_c->m->name_length, nullptr, false);
    }

    return STATE_LOAD_STATUS_CONTINUE;
}

bool conferences_load_state_section(Group_Chats *g_c, const uint8_t *data, uint32_t length, uint16_t type,
                                    State_Load_Status *status)
{
    if (type != STATE_TYPE_CONFERENCES) {
        return false;
    }

    *status = load_conferences(g_c, data, length);
    return true;
}


/* Create new groupchat instance. */
Group_Chats *new_groupchats(Mono_Time *mono_time, Messenger *m)
{
    if (!m) {
        return nullptr;
    }

    Group_Chats *temp = (Group_Chats *)calloc(1, sizeof(Group_Chats));

    if (temp == nullptr) {
        return nullptr;
    }

    temp->mono_time = mono_time;
    temp->m = m;
    temp->fr_c = m->fr_c;
    m->conferences_object = temp;
    m_callback_conference_invite(m, &handle_friend_invite_packet);

    set_global_status_callback(m->fr_c, &g_handle_any_status, temp);

    return temp;
}

/* main groupchats loop. */
void do_groupchats(Group_Chats *g_c, void *userdata)
{
    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        Group_c *g = get_group_c(g_c, i);

        if (!g) {
            continue;
        }

        if (g->status == GROUPCHAT_STATUS_CONNECTED) {
            connect_to_closest(g_c, i, userdata);
            ping_groupchat(g_c, i);
            groupchat_freeze_timedout(g_c, i, userdata);

            if (g->need_send_name) {
                group_name_send(g_c, i, g_c->m->name, g_c->m->name_length);
                g->need_send_name = false;
            }
        }
    }

    // TODO(irungentoo):
}

/* Free everything related with group chats. */
void kill_groupchats(Group_Chats *g_c)
{
    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        del_groupchat(g_c, i, false);
    }

    m_callback_conference_invite(g_c->m, nullptr);
    g_c->m->conferences_object = nullptr;
    free(g_c);
}

/* Return the number of chats in the instance m.
 * You should use this to determine how much memory to allocate
 * for copy_chatlist.
 */
uint32_t count_chatlist(const Group_Chats *g_c)
{
    uint32_t ret = 0;

    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        if (g_c->chats[i].status != GROUPCHAT_STATUS_NONE) {
            ++ret;
        }
    }

    return ret;
}

/* Copy a list of valid chat IDs into the array out_list.
 * If out_list is NULL, returns 0.
 * Otherwise, returns the number of elements copied.
 * If the array was too small, the contents
 * of out_list will be truncated to list_size. */
uint32_t copy_chatlist(const Group_Chats *g_c, uint32_t *out_list, uint32_t list_size)
{
    if (!out_list) {
        return 0;
    }

    if (g_c->num_chats == 0) {
        return 0;
    }

    uint32_t ret = 0;

    for (uint16_t i = 0; i < g_c->num_chats; ++i) {
        if (ret >= list_size) {
            break;  /* Abandon ship */
        }

        if (g_c->chats[i].status > GROUPCHAT_STATUS_NONE) {
            out_list[ret] = i;
            ++ret;
        }
    }

    return ret;
}
