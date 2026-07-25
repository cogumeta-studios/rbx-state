local Signal = require(script.Packages.AcidSignal)

export type Bind<T> = (newValue: T, oldValue: T) -> ()

export type Dependency<T = any> = {
	get: (self: any) -> T,
	bind: (self: any, bind: Bind<T>) -> Bind<T>,
	unbind: (self: any, bind: Bind<T>) -> (Bind<T>, boolean),
}

export type State<T = any> = {
	get: (self: State<T>) -> T,
	set: (self: State<T>, newValue: T) -> T,
	add: (self: State<T>, value: T) -> T,
	sub: (self: State<T>, value: T) -> T,
	mul: (self: State<T>, value: T) -> T,
	div: (self: State<T>, value: T) -> T,
	bind: (self: State<T>, bind: Bind<T>) -> Bind<T>,
	unbind: (self: State<T>, bind: Bind<T>) -> (Bind<T>, boolean),
	binded: (self: State<T>, bind: Bind<T>) -> boolean,
	destroy: (self: State<T>) -> (),
}

local function SharedBind<T>(self: State<T>, bind: Bind<T>): Bind<T>
	local anyself: any = self
	assert(
		not anyself._binds[bind],
		`[State] attempt to re-bind a function`
	)

	anyself._binds[bind] = anyself._signal:Connect(bind)

	return bind
end

local function SharedUnbind<T>(
	self: State<T>,
	bind: Bind<T>
): (Bind<T>, boolean)
	local anyself: any = self
	if not anyself._binds[bind] then return bind, false end

	anyself._binds[bind]:Disconnect()
	anyself._binds[bind] = nil

	return bind, true
end

local function SharedBinded<T>(self: State<T>, bind: Bind<T>): boolean
	local anyself: any = self
	return anyself._binds[bind] ~= nil
end

local function SharedGet<T>(self: State<T>): T
	local anyself: any = self
	return anyself._value
end

local function SharedDestroy<T>(self: State<T>)
	local anyself: any = self
	for _, bind in anyself._binds do
		bind:Disconnect()
	end
	anyself._signal:Destroy()
	anyself._value = nil
	table.clear(self)
end

local function StateSet<T>(self: State<T>, newValue: T): T
	local anyself: any = self
	local oldvalue = anyself._value

	if oldvalue == newValue then return newValue end

	anyself._value = newValue
	anyself._signal:Fire(newValue, oldvalue)

	return newValue
end

local function StateAdd<T>(self: State<T>, value: T): T
	return self:set(self:get() :: any + value :: any)
end

local function StateSub<T>(self: State<T>, value: T): T
	return self:set(self:get() :: any - value :: any)
end

local function StateMul<T>(self: State<T>, value: T): T
	return self:set(self:get() :: any * value :: any)
end

local function StateDiv<T>(self: State<T>, value: T): T
	return self:set(self:get() :: any / value :: any)
end

local function NewState<T>(startValue: T): State<T>
	local self = {} :: State<T>
	local anyself: any = self

	anyself._value = startValue
	anyself._signal = Signal.new()
	anyself._binds = {}

	self.set = StateSet
	self.get = SharedGet
	self.add = StateAdd
	self.sub = StateSub
	self.mul = StateMul
	self.div = StateDiv
	self.bind = SharedBind
	self.unbind = SharedUnbind
	self.binded = SharedBinded
	self.destroy = SharedDestroy

	return self
end

export type Computed<T> = {
	recompute: (self: Computed<T>) -> (),
	get: (self: Computed<T>) -> T,
	bind: (self: Computed<T>, bind: Bind<T>) -> Bind<T>,
	unbind: (self: Computed<T>, bind: Bind<T>) -> (Bind<T>, boolean),
	binded: (self: Computed<T>, bind: Bind<T>) -> boolean,
	destroy: (self: Computed<T>) -> (),
}

local function ComputedRecompute<T>(self: Computed<T>)
	local anyself: any = self
	local oldvalue = anyself._value
	local newvalue = anyself._compute()

	anyself._value = newvalue
	anyself._signal:Fire(newvalue, oldvalue)
end

local function ComputedDestroy<T>(self: Computed<T>)
	local anyself: any = self
	for _, dep in anyself._deps do
		dep:unbind(anyself._depsrecompute)
	end
	SharedDestroy(anyself)
end

local function NewComputed<T>(
	compute: () -> T,
	deps: { Dependency }
): Computed<T>
	local self = {} :: Computed<T>
	local anyself: any = self

	anyself._compute = compute
	anyself._value = compute()
	anyself._signal = Signal.new()
	anyself._binds = {}
	anyself._deps = deps

	self.recompute = ComputedRecompute
	self.get = SharedGet :: any
	self.bind = SharedBind :: any
	self.unbind = SharedUnbind :: any
	self.binded = SharedBinded :: any
	self.destroy = ComputedDestroy

	local recompute = function() self:recompute() end
	anyself._depsrecompute = recompute

	for _, dep in deps do
		dep:bind(recompute)
	end

	return self
end

export type DeltaMode = "add" | "sub" | "mul" | "div"
export type Delta = State<number> & {
	root: State<number>,
	mode: DeltaMode,
	destroy: (self: Delta) -> (),
}

local function DeltaDestroy(self: Delta)
	local anyself: any = self
	local root = self.root
	local mode = self.mode
	local value = self:get()

	if mode == "add" then
		root:sub(value)
	elseif mode == "sub" then
		root:add(value)
	elseif mode == "mul" then
		if value == 0 then
			root:set(anyself._base)
		else
			root:div(value)
		end
	elseif mode == "div" then
		root:mul(value)
	end

	self:unbind(anyself._deltabind)
	SharedDestroy(anyself)
end

local function NewDelta(
	root: State<number>,
	mode: DeltaMode,
	startValue: number?
): Delta
	startValue = startValue or (mode == "mul" or mode == "div") and 1 or 0
	local self = NewState(startValue) :: Delta
	local anyself: any = self

	anyself._base = root:get()

	self.root = root
	self.mode = mode
	self.destroy = DeltaDestroy :: any

	if mode == "add" then
		root:add(startValue)
	elseif mode == "sub" then
		root:sub(startValue)
	elseif mode == "mul" then
		root:mul(startValue)
	elseif mode == "div" then
		assert(startValue ~= 0, "[States.Delta] cannot divide by 0")
		root:div(startValue)
	end

	anyself._deltabind = self:bind(function(newValue, oldValue)
		if mode == "add" then
			anyself._base = root:get() - oldValue
			root:add(newValue - oldValue)
		elseif mode == "sub" then
			anyself._base = root:get() + oldValue
			root:sub(newValue - oldValue)
		elseif mode == "mul" then
			if oldValue == 0 then
				root:set(anyself._base * newValue)
			else
				anyself._base = root:get() / oldValue
				root:mul(newValue / oldValue)
			end
		elseif mode == "div" then
			assert(newValue ~= 0, "[States.Delta] cannot divide by 0")
			anyself._base = root:get() * oldValue
			root:div(newValue / oldValue)
		end
	end)

	return self
end

return {
	NewState = NewState,
	NewComputed = NewComputed,
	NewDelta = NewDelta,
}
