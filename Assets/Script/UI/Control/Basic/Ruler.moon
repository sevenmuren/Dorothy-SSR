Dorothy!
RulerView = require "UI.View.Control.Basic.Ruler"
import Round from require "Utils"

Class RulerView,
	__init:(args)=>
		{:y,:width,:height,:fontName,:fontSize,:fixed} = args
		viewSize = View.size
		halfW = width/2
		halfH = height/2
		interval = 10
		indent = 100
		fontSize or= 12
		vsCache = {}
		@endPosY = y
		@isFixed = fixed or true

		labels = {}
		labelList = {}
		len = nil
		do
			posX = @intervalNode.anchor.x*width
			center = Round posX/100
			len = Round (posX+halfW)/100-center
			len = 1+math.max (center - Round (posX-halfW)/100),len
			for i = center-len,center+len
				pos = i*100
				label = with Label fontName,fontSize
					.text = tostring(pos/100*indent)
					.scaleX = 1/@intervalNode.scaleX
					.position = Vec2 pos,halfH-18-fontSize
					.tag = tostring pos
				@intervalNode\addChild label
				labels[pos] = label
				table.insert labelList,label

		moveLabel = (label,pos)->
			labels[tonumber label.tag] = nil
			labels[pos] = with label
				.text = tostring pos/100*indent
				.scaleX = 1/@intervalNode.scaleX
				.position = Vec2 pos,halfH-18-fontSize
				.tag = tostring pos

		updateLabels = ->
			posX = @intervalNode.anchor.x*width
			center = math.floor posX/100
			right = center+len
			left = center-len
			insertPos = 1
			for i = left,right
				pos = i*100
				if labels[pos]
					break
				else
					label = table.remove labelList
					table.insert labelList,insertPos,label
					insertPos += 1
					moveLabel label,pos
			insertPos = #labelList
			for i = right,left,-1
				pos = i*100
				if labels[pos]
					break
				else
					label = table.remove labelList,1
					table.insert labelList,insertPos,label
					insertPos -= 1
					moveLabel label,pos

			scale = @intervalNode.scaleX
			current = Round @intervalNode.anchor.x*width/interval
			delta = 1+math.ceil halfW/scale/interval
			max = current+delta
			min = current-delta
			count = 1
			vs = {}
			for i = min,max
				posX = i*interval
				v = vsCache[count]
				if v then v\set posX,halfH
				else
					v = Vec2 posX,halfH
					vsCache[count] = v
				vs[count] = v
				count += 1
				v = vsCache[count]
				if v then v\set posX,halfH-(i%10 == 0 and fontSize+6 or fontSize-2)
				else
					v = Vec2 posX,halfH-(i%10 == 0 and fontSize+6 or fontSize-2)
					vsCache[count] = v
				vs[count] = v
				count += 1
				v = vsCache[count]
				if v then v\set posX,halfH
				else
					v = Vec2 posX,halfH
					vsCache[count] = v
				vs[count] = v
				count += 1
			@intervalNode\set vs,Color 0xffffffff

		updateIntervalTextScale = (scale)->
			@intervalNode\eachChild (child)->
				child.scaleX = scale

		@makeScale = (scale)=>
			scale = math.min scale,5
			@intervalNode.scaleX= scale
			-- unscale interval text --
			updateIntervalTextScale 1/scale
			updateLabels!

		@makeScaleTo = (scale)=>
			@intervalNode\perform ScaleX 0.5,@intervalNode.scaleX,scale,Ease.OutQuad
			-- manually update and unscale interval text --
			@intervalNode\schedule once -> cycle 0.5,-> updateIntervalTextScale 1/@intervalNode.scaleX
			updateLabels!

		_value = 0
		_max = 0
		_min = 0

		switch Application.platform
			when "macOS", "Windows"
				@addChild with Node!
					.size = Size width,height
					.touchEnabled = true
					.swallowMouseWheel = true
					\slot "MouseWheel",(delta)->
						newVal = @getValue!+delta.y*indent/10
						@setValue _min < _max and math.min(math.max(_min, newVal),_max) or newVal

		@setIndent = (ind)=>
			indent = ind
			for i,label in pairs labels
				label.text = tostring ind*i/100
		@getIndent = => indent

		@lastValue = nil
		@setValue = (v)=>
			_value = v
			val = _min < _max and math.min(math.max(_value,_min),_max) or _value
			val = @isFixed and Round(val/(indent/10))*(indent/10) or val
			val = 0 if val == -0
			if @lastValue ~= val
				@lastValue = val
				@emit "Changed",val
			posX = v*10*interval/indent
			@intervalNode.anchor = Vec2 posX/width,0
			updateLabels!

		@getValue = => _value
		@getPos = => _value*10*interval/indent

		@setLimit = (min,max)=>
			_max = max
			_min = min

		time = 0
		startPos = 0
		updateReset = (deltaTime)->
			return if _min >= _max
			scale = @intervalNode.scaleX
			time = time + deltaTime
			t = time/1
			t = t/0.1 if scale < 1
			t = math.min 1,t
			yVal = nil
			if startPos < _min
				yVal = startPos + (_min-startPos) * Ease\func scale < 1 and Ease.Linear or Ease.OutElastic,t
			elseif startPos > _max
				yVal = startPos + (_max-startPos) * Ease\func scale < 1 and Ease.Linear or Ease.OutElastic,t
			@setValue ((yVal and yVal or 0)-_value)/scale+_value
			@unschedule! if t == 1.0

		isReseting = ->
			_min < _max and (_value > _max or _value < _min)

		startReset = ->
			startPos = _value
			time = 0
			@schedule updateReset

		_v = 0
		_s = 0
		updateSpeed = (deltaTime)->
			return if _s == 0
			_v = _s / deltaTime
			_s = 0

		updatePos = (deltaTime)->
			val = viewSize.height*2
			a = _v > 0 and -val or val
			yR = _v > 0
			_v = _v + a*deltaTime
			if _v < 0 == yR
				_v = 0
				a = 0
			ds = _v * deltaTime + a*(0.5*deltaTime*deltaTime)
			newValue = _value-ds*indent/(interval*10)
			@setValue (newValue-_value)/@intervalNode.scaleY+_value
			if _v == 0 or isReseting!
				if isReseting! then startReset!
				else @unschedule!

		@slot "TapFilter", (touch)->
			touch.enabled = false unless touch.id == 0

		@slot "TapBegan",->
			_s = 0
			_v = 0
			@schedule updateSpeed

		@slot "TapMoved",(touch)->
			deltaX = touch.delta.x
			v = _value-deltaX*indent/(interval*10)
			padding = 0.5*indent
			if _max > _min
				d = 1
				if v > _max
					d = (v - _max)*3/padding
				elseif v < _min
					d = (_min - v)*3/padding
				v = _value+(v - _value)/(d < 1 and 1 or d*d)
			@setValue (v-_value)/@intervalNode.scaleX+_value
			_s += deltaX

		@slot "TapEnded",->
			if isReseting!
				startReset!
			elseif _v ~= 0
				@schedule updatePos

	show: (default,min,max,ind,callback)=>
		@setLimit min,max
		@setIndent ind
		@slot("Changed")\set callback
		@lastValue = nil
		@setValue default
		@visible = true
		@perform Spawn(
			Y 0.5,@endPosY+30,@endPosY,Ease.OutBack
			Opacity 0.3,@opacity,1
		)

	hide: =>
		return unless @visible
		@slot "Changed",nil
		@unschedule!
		@perform Sequence(
			Spawn(
				Y 0.5,@y,@endPosY+30,Ease.InBack
				Opacity 0.5,@opacity,0
			),
			Hide!
		)
