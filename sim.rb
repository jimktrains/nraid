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


$disks = [[],[],[],[],[]]
$disk_sizes = [5,5,6,7,8]



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
		else 
			a = [ (block % $common[block].size),  $common[block].size-1-(block % $common[block].size) ]
			a[0] = (a[0] + 1 % $common[block].size) if a[0] == a[1]
			a
	end
	$data_blocks[block] =  
		case $storage_style[block]
			when :unused then []
			when :duplicate then [$common[block][0]]
			else $common[block].select_with_index { |d,i| not $parity[block].include? d }
		end
end


print "%d Disks\n" % $disk_sizes.size
print "Sizes:\n"
$disk_sizes.each_with_index do |d, i|
	print "Disk %2d: %d\n" % [i,d]
end
print "\nDisks with groups in common:\n"
$common.each_with_index { |d,i| print "Group %2d: Disks: %s\n" % [i,d.join(',')]}
print "\nGroup storage engine:\n"
$storage_style.each_with_index { |d,i| print "Group %2d: %s\n" % [i,d]}
print "\nUsable Blocks in each group:\n"
$total_storage.each_with_index { |d,i| print "Group %2d: Blocks: %d\n" % [i,d]}
print "\nMax block available for storage: %d\n" % [max_block = ($total_storage.inject{ |ttl,x| ttl.to_i + x.to_i }) -1]
print "\nDisks with parity for a group:\n"
$parity.each_with_index { |d,i| print "Group %2d: Disks: %s\n" % [i,d.join(',')]}
print "\nDisks with data for a group:\n"
$data_blocks.each_with_index { |d,i| print "Group %2d: Disks: %s\n" % [i,d.join(',')]}

def print_disk_array
	block_width = $disks.map { |d| d.map { |i| i.length }.max }.max
	sep_width = (block_width + 4)
	$disks.each_with_index do |d,i|
		print "%s" % ('-' * sep_width)
	end
	print "\n"
	$disks.each_with_index do |d,i|
		print "%#{block_width}s|  |" % ["Disk #{i}"]
	end
	print "\n"
	$disks.each_with_index do |d,i|
		print "%s" % ('-' * sep_width)
	end
	print "\n"
	$disk_sizes.max.times do |i|
		$disks.each_with_index do |d,di|
			parity_type = case $storage_style[i]
				when :unused then 'NN'
				when :duplicate then 'DD'
				when :single_parity then 'SP'
				else 
					pt = ''
					$parity[i].each_with_index do |p, pi|
						# pp p
						# pp di
						# pp pi
						# pp '---'
						if p == di then
							pt = case pi
								when 0 then 'P1'
								when 1 then 'P2'
							end
						end
					end
					pt
			end
			print "%#{block_width}s|%2s|" % [(d[i] || ($disk_sizes[di] < (i+1) ? "--DNE--" : "--NU--")), $parity[i].include?(di) ? parity_type : ' ']
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
			$parity[group].each_with_index do |p, i| 
				$disks[p][block_on_disk] = case i
					when 0 then $data_blocks[group].inject('') { |ttl, b| ttl + $disks[b][block_on_disk].to_s + '+' }
					when 1 then $data_blocks[group].inject('') { |ttl, b| ttl + $disks[b][block_on_disk].to_s + '*' }
				end
			end
	end
	
end

(0..max_block).each { |n| write_block n, 'hi' + n.to_s }
print "Wrote 'hi<block number>' to each block\n"
print_disk_array

write_block 3, 'test'
print "Wrote 'test' to block 3\n"
print_disk_array

write_block 15, 'wazup'
print "Wrote 'wazup' to block 15\n"
print_disk_array

write_block 17, 'wow'
print "Wrote 'wow' to block 17\n"
print_disk_array