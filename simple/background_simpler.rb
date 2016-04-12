#!/usr/local/bin/ruby

require_relative 'simplifier.rb'

s = Simpler.new()

while(true) do
	s.simplify()
	sleep(0.02)
end
