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

#ifndef WEBDRIVER_IE_SESSION_H_
#define WEBDRIVER_IE_SESSION_H_

#include <string>
#include <memory>

using namespace std;

namespace webdriver {

class Session {
public:
	Session(int port);
	virtual ~Session(void);

	virtual std::wstring Initialize(void) = 0;
	virtual void ShutDown(void) = 0;
	virtual bool ExecuteCommand(const std::wstring& serialized_command, std::wstring* serialized_response) = 0;

protected:
	int port(void) const { return this->port_; }

private:
	int port_;
};

typedef std::tr1::shared_ptr<Session> SessionHandle;

} // namespace webdriver

#endif // WEBDRIVER_IE_SESSION_H_
