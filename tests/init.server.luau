local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateBuilder = require(ReplicatedStorage.state)
local State, Computed = StateBuilder.NewState, StateBuilder.NewComputed
local Specium = require(ReplicatedStorage.DevPackages.Specium)

local expect = Specium.expect

local suite = Specium.suite("State", function(ctx)
	ctx.describe("State", function(ctx)
		ctx.it("should create a state with initial value", function()
			local state = State(123)

			expect(state:get()).toBe(123)

			return nil
		end)

		ctx.it("should set and get values properly", function()
			local state = State(0)

			state:set(42)

			expect(state:get()).toBe(42)

			return nil
		end)

		ctx.it("should return the assigned value from set", function()
			local state = State(0)

			expect(state:set(55)).toBe(55)

			return nil
		end)

		ctx.it("should notify binds when value changes", function()
			local state = State(0)

			local newValue
			local oldValue

			state:bind(function(new, old)
				newValue = new
				oldValue = old
			end)

			state:set(10)

			expect(newValue).toBe(10)
			expect(oldValue).toBe(0)

			return nil
		end)

		ctx.it("should report binded correctly", function()
			local state = State(0)

			local callback = function() end

			expect(state:binded(callback)).toBe(false)

			state:bind(callback)

			expect(state:binded(callback)).toBe(true)

			return nil
		end)

		ctx.it("should unbind properly", function()
			local state = State(0)

			local calls = 0

			local callback = function()
				calls += 1
			end

			state:bind(callback)
			state:unbind(callback)

			state:set(1)

			expect(calls).toBe(0)

			return nil
		end)

		ctx.it(
			"should return false when unbinding a non-existent callback",
			function()
				local state = State(0)

				local callback = function() end

				local _, success = state:unbind(callback)

				expect(success).toBe(false)

				return nil
			end
		)

		ctx.it(
			"should return true when unbinding an existing callback",
			function()
				local state = State(0)

				local callback = function() end

				state:bind(callback)

				local _, success = state:unbind(callback)

				expect(success).toBe(true)

				return nil
			end
		)
	end)

	ctx.describe("Computed", function(ctx)
		ctx.it("should compute initial value", function()
			local state = State(5)

			local computed = Computed(
				function() return state:get() * 2 end,
				{ state }
			)

			expect(computed:get()).toBe(10)

			return nil
		end)

		ctx.it("should recompute manually", function()
			local state = State(5)

			local computed = Computed(
				function() return state:get() * 2 end,
				{ state }
			)

			state:set(10)

			computed:recompute()

			expect(computed:get()).toBe(20)

			return nil
		end)

		ctx.it(
			"should recompute automatically when dependency changes",
			function()
				local state = State(5)

				local computed = Computed(
					function() return state:get() * 2 end,
					{ state }
				)

				state:set(10)

				expect(computed:get()).toBe(20)

				return nil
			end
		)

		ctx.it("should notify binds when recomputed", function()
			local state = State(1)

			local computed = Computed(
				function() return state:get() + 1 end,
				{ state }
			)

			local newValue
			local oldValue

			computed:bind(function(new, old)
				newValue = new
				oldValue = old
			end)

			state:set(10)

			expect(newValue).toBe(11)
			expect(oldValue).toBe(2)

			return nil
		end)

		ctx.it("should support multiple dependencies", function()
			local a = State(10)
			local b = State(20)

			local computed = Computed(
				function() return a:get() + b:get() end,
				{ a, b }
			)

			expect(computed:get()).toBe(30)

			a:set(5)

			expect(computed:get()).toBe(25)

			b:set(100)

			expect(computed:get()).toBe(105)

			return nil
		end)
	end)

	ctx.describe("Destroy", function(ctx)
		ctx.it("should clear state value on destroy", function()
			local state = State(123)

			state:destroy()

			expect(next(state :: any)).toBe(nil)

			return nil
		end)

		ctx.it(
			"should unbind computed from dependencies on destroy",
			function()
				local state = State(1)

				local computed = Computed(
					function() return state:get() * 2 end,
					{ state }
				)

				computed:destroy()

				state:set(10)

				expect(next(computed :: any)).toBe(nil)

				return nil
			end
		)
	end)
end)

local output = Specium.run(suite)
print(output)
