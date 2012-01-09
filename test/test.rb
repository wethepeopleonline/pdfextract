#!/usr/bin/env ruby

require "json"
require "commander/import"
require_relative "../lib/pdf-extract"

program :name, "test.rb"
program :version, "0.0.1"
program :description, "Test PDF reference extraction against previous results."

def expected_refs file_path
  json_path = file_path.sub(/\.pdf\Z/, ".json")
  if File.exists? json_path
    File.open json_path, "r" do |f|
      JSON.parse f
    end
  else
    nil
  end
end

def actual_refs file_path
  pdf = PdfExtract.parse file_path do |pdf|
    pdf.references
  end
  puts pdf.spatial_objects
  pdf.spatial_objects[:references]
end

def record_refs file_path, options={}
  options = {:suffix => ".json", :refs => nil}.merge options
  File.open file_path.sub(/\.pdf\Z/, options[:suffix]), "w" do |f|
    if options[:refs].nil?
      f.write actual_refs(file_path).to_json
    else
      f.write options[:refs].to_json
    end
  end
end

def refs_equal? a, b
  if a.count != b.count
    {:match => false, :reason => "Differing number of references."}
  else
    status = {:match => true}
    
    a.each_index do |ref, idx|
      if ref[:content] != b[idx][:content]
        status = {
          :match => false,
          :reason => "Reference content does not match at index #{idx}."
        }
        break
      end
    end
    
    status
  end
end

def run_for_directory dir
  pass_count = 0
  fail_count = 0
  count = 0

  total = Dir.entries(dir).count { |e| e.end_with?(".pdf") }

  puts "Estimated run time #{(total * 30) / 60} minutes.\n\n"
  
  Dir.foreach dir do |filename|
    
    if filename.end_with?(".pdf")
      path = File.join(dir, filename)
      print "\##{count + 1} #{filename} ......... "

      expected = expected_refs path

      if expected.nil?
        puts "FAIL"
        puts "\tNo expected results for this PDF."
        puts "\tWriting actual output..."
        record_refs path, {:suffix => ".json.fail"}
        fail_count = fail_count.next
      else
        actual = actual_refs path
        match_status = refs_equal? expected, actual
        
        if match_status[:match]
          puts "PASS"
          pass_count = pass_count.next
        else
          puts "FAIL"
          puts "\t" + match_status[:reason]
          puts "\tWriting failed output..."
          record_refs path, {:suffix => ".json.fail", :refs => actual}
          fail_count = fail_count.next
        end
      end
      
      count = count.next
      puts "\tPassed: #{pass_count}, Failed: #{fail_count}, Total: #{total}"
      puts ""
    end
  end
end

command :run do |c|
  c.action do |args, options|
    args.each do |arg|
      run_for_directory arg
    end
  end
end

command :record do |c|
  c.action do |args, options|
    args.each do |arg|
      record_refs arg
    end
  end
end