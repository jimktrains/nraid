#!/usr/bin/ruby
# nRaid simulator
# TODO:
# * Clean up code
# * Encapsulate code better
#
# Under the GPLv3 license
#
# Master Plan: incorperate into a fork of mdadm (they can choose to merge it in or not)
require 'pp'

module Enumerable
	def select_with_index
		index = -1
		(block_given? && self.class == Range || self.class == Array)  ?  select { |x| index += 1; yield(x, index) }  :  self
	end
	def map_with_index
		index = -1
		(block_given? && self.class == Range || self.class == Array)  ?  map { |x| index += 1; yield(x, index) }  :  self
	end

	def select_by_index
		index = -1
		if (block_given? && self.class == Range || self.class == Array)  then
			x = map { |x| index += 1; yield(x) ? index : nil }
			x.select { |x| x }
		else
			self
		end
	end
	
	def sum
		ttl = 0
		inject{|ttl,x| ttl + x.to_i }
	end
end


$disks = [[],[],[],[]]
$disk_sizes = [5,6,6,7]



$common = []
$storage_style = []
$total_storage = []
$max_block = []
ttl = 0
$parity = []
$data_blocks = []
$disk_sizes.max.times do |block|
	$common[block] = $disk_sizes.select_by_index { |d| block < d  }
	$storage_style[block] = case $common[block].size
		when 0..1 then :unused
		when 2 then    :duplicate
		when 3 then    :single_parity
		else           :dual_parody
	end
	$total_storage[block] = case $storage_style[block]
		when :unused then 0
		when :duplicate then 1
		when :single_parity then $common[block].size - 1
		else $common[block].size - 2
	end
	$max_block[block] = [ttl, ttl = ttl.to_i + $total_storage[block].to_i]
	$parity[block] = case $storage_style[block]
		when :unused then []
		when :duplicate then [$common[block][1]]
		when :single_parity then [ block % $common[block].size ]
		else [ (block % $common[block].size),  $common[block].size-1-(block % $common[block].size) ]
	end
	$data_blocks[block] =  
		case $storage_style[block]
			when :unused then []
			when :duplicate then [$common[block][0]]
			else $common[block].select_with_index { |d,i| not $parity[block].include? d }
		end
end



pp "Disks with groups in common:"
pp $common
pp "Group storage:"
pp $storage_style
pp "Blocks in each group"
pp $total_storage
pp "Max block available for storage"
pp max_block = ($total_storage.inject{ |ttl,x| ttl.to_i + x.to_i }) -1
pp "Max and min blocks in each group"
pp $max_block
pp "Which disk parity is on in each group"
pp $parity
pp "Which disk data is on in each group"
pp $data_blocks

def print_disk_array
	block_width = 13
	sep_width = (block_width + 3)
	$disks.each_with_index do |d,i|
		print "%s" % ('-' * sep_width)
	end
	print "\n"
	$disks.each_with_index do |d,i|
		print "%#{block_width}s| |" % ["Disk #{i}"]
	end
	print "\n"
	$disks.each_with_index do |d,i|
		print "%s" % ('-' * sep_width)
	end
	print "\n"
	$disk_sizes.max.times do |i|
		$disks.each_with_index do |d,di|
			parity_type = case $storage_style[i]
				when :unused then 'N'
				when :duplicate then 'D'
				else 'P'
			end
			print "%#{block_width}s|%1s|" % [(d[i] || ($disk_sizes[di] < (i+1) ? "--DNE--" : "--NU--")), $parity[i].include?(di) ? parity_type : ' ']
		end
		print "\n"
	end
	$disks.each_with_index do |d,i|
		print "%s" % ('-' * sep_width)
	end
	print "\n"
end

def write_block(block, data)
	group = $max_block.select_by_index { |d,i| d <= block}.max
	num_in = block - $max_block[group][0]

	disk = $data_blocks[group][num_in]
	block_on_disk = group
	
	$disks[disk][block_on_disk] = data
	case $storage_style[group]
		when :unused then ''
		when :duplicate then $disks[$parity[group][0]][block_on_disk] = data
		else
			ttl = ''
			# Need to fix:-\
			parity = $data_blocks[group].inject('') { |ttl, b| ttl + $disks[b][block_on_disk].to_s + '+' }
			$parity[group].each { |p| $disks[p][block_on_disk] = parity }
	end
	
end

(0..max_block).each { |n| write_block n, 'hi' + n.to_s }

print_disk_array

write_block 3, 'test'

print_disk_array

write_block 10, 'wazup'

print_disk_array