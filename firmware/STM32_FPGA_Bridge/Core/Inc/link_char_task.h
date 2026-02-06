/*
 * link_char_task.h
 *
 *  Created on: Feb 5, 2026
 *      Author: treyparker
 */

#ifndef INC_LINK_CHAR_TASK_H_
#define INC_LINK_CHAR_TASK_H_

#include <stdbool.h>
#include "app_config.h"

#if ENABLE_LINK_CHAR

#include "link_char.h"

void StartLinkCharTask(void *argument);
bool link_char_task_is_complete(void);
bool link_char_task_passed(void);
const link_char_results_t* link_char_task_get_results(void);

#endif

#endif /* INC_LINK_CHAR_TASK_H_ */
