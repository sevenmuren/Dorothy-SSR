/* Copyright (c) 2017 Jin Li, http://www.luvfight.me

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#include "Const/Header.h"
#include "Basic/Scheduler.h"
#include "Animation/Action.h"
#include "Support/Array.h"
#include "Node/Node.h"

NS_DOROTHY_BEGIN

class FuncWrapper : public Object
{
public:
	virtual bool update(double deltaTime) override
	{
		return func(deltaTime);
	}
	function<bool (double)> func;
	list<Ref<Object>>::iterator it;
	CREATE_FUNC(FuncWrapper);
protected:
	FuncWrapper(const function<bool (double)>& func):func(func) { }
	DORA_TYPE_OVERRIDE(FuncWrapper);
};

vector<Ref<Object>> Scheduler::_updateItems;

Scheduler::Scheduler():
_timeScale(1.0f),
_actionList(Array::create())
{ }

void Scheduler::setTimeScale(float value)
{
	_timeScale = std::max(0.0f, value);
}

float Scheduler::getTimeScale() const
{
	return _timeScale;
}

void Scheduler::schedule(Object* object)
{
	// O(1) insert operation
	_updateMap[object] = _updateList.insert(_updateList.end(), MakeRef(object));
}

void Scheduler::schedule(const function<bool (double)>& handler)
{
	FuncWrapper* func = FuncWrapper::create(handler);
	func->it = _updateList.insert(_updateList.end(), Ref<Object>(func));
}

void Scheduler::unschedule(Object* object)
{
	auto it = _updateMap.find(object);
	if (it != _updateMap.end())
	{
		// O(1) remove operation
		_updateList.erase(it->second);
		_updateMap.erase(it);
	}
}

void Scheduler::schedule(Action* action)
{
	if (action && action->_target && !action->isRunning())
	{
		action->_order = _actionList->getCount();
		_actionList->add(action);
		if (action->updateProgress())
		{
			Ref<Action> actionRef(action);
			Ref<Node> targetRef(action->_target);
			unschedule(actionRef);
			targetRef->removeAction(actionRef);
			targetRef->emit("ActionEnd"_slice, actionRef.get(), targetRef.get());
		}
	}
}

void Scheduler::unschedule(Action* action)
{
	Ref<> ref(action);
	if (action && action->_target && action->isRunning()
		&& _actionList->get(action->_order) == action)
	{
		_actionList->set(action->_order, nullptr);
		action->_order = Action::InvalidOrder;
	}
}

bool Scheduler::update(double deltaTime)
{
	// not save _it and _deltaTime on the stack memory
	_deltaTime = deltaTime * _timeScale;

	/* update actions */
	int i = 0, count = _actionList->getCount();
	while (i < count)
	{
		Ref<Action> action(_actionList->get(i).to<Action>());
		if (action)
		{
			if (!action->isPaused())
			{
				int lastIndex = action->_order;
				action->_eclapsed += s_cast<float>(_deltaTime) * action->_speed;
				if (action->updateProgress())
				{
					if (action->_order == lastIndex)
					{
						Node* target = action->_target;
						unschedule(action);
						target->removeAction(action);
						target->emit("ActionEnd"_slice, action.get(), target);
					}
				}
			}
		}
		else
		{
			_actionList->fastRemoveAt(i);
			if (i < _actionList->getCount())
			{
				Action* action = _actionList->get(i).to<Action>();
				if (action)
				{
					action->_order = i;
				}
			}
			i--;
			count--;
		}
		i++;
	}

	/* update scheduled items */
	_updateItems.reserve(_updateList.size());
	_updateItems.insert(_updateItems.begin(), _updateList.begin(), _updateList.end());
	for (const auto& item : _updateItems)
	{
		if (item->update(_deltaTime))
		{
			FuncWrapper* func = DoraCast<FuncWrapper>(item.get());
			if (func)
			{
				_updateList.erase(func->it);
			}
			else unschedule(item);
		}
	}
	_updateItems.clear();
	return false;
}

NS_DOROTHY_END
