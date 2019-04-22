#include "timer.h"
#include <string.h>

void add_event(BS_List* event_list, uint32_t event_type, uint32_t friend_number, uint32_t interval, void* user_data, tox_timeout_cb* cb) {
	if (!event_list) {
		return;
	}
	struct Event_Node event_node;
	memset(&event_node, 0, sizeof(event_node));
	event_node.event_type = event_type;
	event_node.interval = interval;
	event_node.friend_number = friend_number;
	event_node.mono_time = mono_time_new();
	if (event_node.mono_time != nullptr) {
		event_node.lastdump = mono_time_get(event_node.mono_time); 
	}
	event_node.user_data = user_data;
	event_node.cb = cb;
	bs_list_add(event_list, (const uint8_t *)&event_node, event_type);
}

void del_event(BS_List* event_list, Event_Node* event_node) {
	if (!event_list && !event_node) {
		return;
	}
	if (event_node->mono_time) {
		mono_time_free(event_node->mono_time);
		event_node->mono_time = nullptr;
	}
	int res = bs_list_remove(event_list, (const uint8_t *)event_node, event_node->event_type);
	if (!res) {
		return;
	}
}

void event_loop(Tox* tox, BS_List* event_list) {
	if (!event_list) {
		return;
	}
	for (int i = 0; i < event_list->n; i++) {
		const void* start_address = event_list->data + event_list->element_size* i;
		Event_Node* event_node = (Event_Node*)start_address;
		if (event_node && event_node->mono_time) {
			mono_time_update(event_node->mono_time);
			if (mono_time_is_timeout(event_node->mono_time, event_node->lastdump, event_node->interval)) {
				event_node->lastdump = mono_time_get(event_node->mono_time);	
				event_node->cb(tox, event_node->friend_number, event_node->event_type, event_node->user_data);
				del_event(event_list, event_node);
				break;
			}
		}
	}	
}


