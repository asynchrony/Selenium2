// Copyright 2011 WebDriver committers
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef WEBDRIVER_IE_SWITCHTOWINDOWCOMMANDHANDLER_H_
#define WEBDRIVER_IE_SWITCHTOWINDOWCOMMANDHANDLER_H_

#include "Session.h"

namespace webdriver {

class SwitchToWindowCommandHandler : public CommandHandler {
public:
	SwitchToWindowCommandHandler(void) {
	}

	virtual ~SwitchToWindowCommandHandler(void) {
	}

protected:
	void ExecuteInternal(const Session& session, const LocatorMap& locator_parameters, const ParametersMap& command_parameters, Response * response) {
		ParametersMap::const_iterator name_parameter_iterator = command_parameters.find("name");
		if (name_parameter_iterator == command_parameters.end()) {
			response->SetErrorResponse(400, "Missing parameter: name");
			return;
		} else {
			std::wstring found_browser_handle = L"";
			std::string desired_name = name_parameter_iterator->second.asString();

			std::vector<std::wstring> handle_list;
			session.GetManagedBrowserHandles(&handle_list);
			for (unsigned int i = 0; i < handle_list.size(); ++i) {
				BrowserHandle browser_wrapper;
				int get_handle_loop_status_code = session.GetManagedBrowser(handle_list[i], &browser_wrapper);
				if (get_handle_loop_status_code == SUCCESS) {
					std::string browser_name = CW2A(browser_wrapper->GetWindowName().c_str(), CP_UTF8);
					if (browser_name == desired_name) {
						found_browser_handle = handle_list[i];
						break;
					}

					std::string browser_handle = CW2A(handle_list[i].c_str(), CP_UTF8);
					if (browser_handle == desired_name) {
						found_browser_handle = handle_list[i];
						break;
					}
				}
			}

			if (found_browser_handle == L"") {
				response->SetErrorResponse(ENOSUCHWINDOW, "No window found");
				return;
			} else {
				// Reset the path to the focused frame before switching window context.
				BrowserHandle current_browser;
				int status_code = session.GetCurrentBrowser(&current_browser);
				if (status_code == SUCCESS) {
					current_browser->SetFocusedFrameByElement(NULL);
				}

				Session& mutable_session = const_cast<Session&>(session);
				mutable_session.set_current_browser_id(found_browser_handle);
				status_code = session.GetCurrentBrowser(&current_browser);
				current_browser->set_wait_required(true);
				response->SetResponse(SUCCESS, Json::Value::null);
			}
		}
	}
};

} // namespace webdriver

#endif // WEBDRIVER_IE_SWITCHTOWINDOWCOMMANDHANDLER_H_