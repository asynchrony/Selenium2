#ifndef WEBDRIVER_IE_GOTOURLCOMMANDHANDLER_H_
#define WEBDRIVER_IE_GOTOURLCOMMANDHANDLER_H_

#include "BrowserManager.h"

namespace webdriver {

class GoToUrlCommandHandler : public WebDriverCommandHandler {
public:
	GoToUrlCommandHandler(void) {
	}

	virtual ~GoToUrlCommandHandler(void) {
	}

protected:
	void GoToUrlCommandHandler::ExecuteInternal(BrowserManager *manager, std::map<std::string, std::string> locator_parameters, std::map<std::string, Json::Value> command_parameters, WebDriverResponse * response) {
		if (command_parameters.find("url") == command_parameters.end()) {
			response->SetErrorResponse(400, "Missing parameter: url");
			return;
		} else {
			BrowserWrapper *browser_wrapper;
			int status_code = manager->GetCurrentBrowser(&browser_wrapper);
			if (status_code != SUCCESS) {
				response->SetErrorResponse(status_code, "Unable to get browser");
				return;
			}
			std::string url = command_parameters["url"].asString();
			CComVariant url_variant(url.c_str());
			CComVariant dummy;

			// TODO: check HRESULT for error
			HRESULT hr = browser_wrapper->browser()->Navigate2(&url_variant, &dummy, &dummy, &dummy, &dummy);
			browser_wrapper->set_wait_required(true);

			//browser_wrapper->set_path_to_frame(L"");
			browser_wrapper->SetFocusedFrameByElement(NULL);
			response->SetResponse(SUCCESS, Json::Value::null);
		}
	}
};

} // namespace webdriver

#endif // WEBDRIVER_IE_GOTOURLCOMMANDHANDLER_H_