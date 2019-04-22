#ifndef TIMEOUT_LIST_H
#define TIMEOUT_LIST_H
#include <time.h>
#include "list.h"
#include "mono_time.h"
#include "ccompat.h"
#include "crypto_core.h"

typedef struct Tox Tox;

/**
 * decare callback function
 */
typedef void tox_timeout_cb (Tox* tox, uint32_t friend_number, uint32_t event_type, void* user_data);
/**
 * timer info
 * public_key who' event to be triggered
 */ 
typedef struct Event_Node {
	uint32_t event_type;
	uint32_t interval;
	time_t lastdump;	
	Mono_Time* mono_time; 	
	uint32_t friend_number;
	// timeout callback functions
	tox_timeout_cb* cb;
	void* user_data;
} Event_Node;  


/**
 * add a event node to list
 */
void add_event(BS_List* event_list, uint32_t event_type, uint32_t friend_number, uint32_t interval, void* user_data, tox_timeout_cb* cb);

/**
 * del event node from list
 */
void del_event(BS_List* event_list, Event_Node* event_node);

/**
 * dispatch event
 */
void event_loop(Tox* tox, BS_List* event_list);

#endif
