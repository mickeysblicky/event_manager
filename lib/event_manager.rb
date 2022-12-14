require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
    zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
    numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    arr = number.split("")
    arr.each_with_index do |c, i|
        if !numbers.any? {|n| n == c}
            number.delete!(c)
        end
    end

    if number.length < 10 
        number = nil
    elsif number.length == 10
        return number
    elsif number.length == 11 && number[0] == "1"
        number.slice!(0)
        return number
    elsif number.length == 11 && number[0] != "1"
        number = nil
    elsif number.length > 11 
        number = nil
    end
end

def best_reg_hours(con)
    hours_arr = []

    con.each do |row|
        t = Time.strptime(row[:regdate], "%m/%d/%y %k:%M")
        hours_arr << t.hour
    end
    hours = hours_arr.uniq
    
    hours.sort_by! {|h| hours_arr.count(h)}.reverse!

    hours.each_with_index do |h, i|
        puts "Hour: #{h} | Reg-count: #{hours_arr.count(h)}"
    end
    
    puts "Peak hours: #{hours[0]}:00, #{hours[1]}:00"
end

def day_of_week(c)
    days_arr = []
    day_names = {0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday'}

    c.each do |row|
        t = Date.strptime(row[:regdate], "%m/%d/%y %k:%M")
        days_arr << t.wday
    end
    days = days_arr.uniq

    days.sort_by! {|d| days_arr.count(d)}.reverse!

    days.each_with_index do |d, i|
        puts "Day: #{day_names[d]} | Reg-count: #{days_arr.count(d)}"
    end

    puts "Peak registration days: #{day_names[days[0]]}, #{day_names[days[1]]}"
end

def legislators_by_zipcode(zip)
    civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
    civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
    
    begin
        civic_info.representative_info_by_address(
            address: zip,
            levels: 'country',
            roles: ['legislatorUpperBody', 'legislatorLowerBody']
        ).officials
    rescue
        'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
    end
end

def save_thank_you_letter(id, form_letter)
    Dir.mkdir('output') unless Dir.exist?('output')
    
    filename = "output/thanks_#{id}.html"
    
    File.open(filename, 'w') do |file|
        file.puts form_letter
    end
end

puts 'EventManager initialized.'

contents = CSV.open(
    'event_attendees.csv',
    headers: true,
    header_converters: :symbol
)

contents2 = CSV.open(
    'event_attendees.csv',
    headers: true,
    header_converters: :symbol
)

best_reg_hours(contents)

day_of_week(contents2)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    phone = clean_phone_number(row[:homephone])
    registration = row[:regdate]
    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    #save_thank_you_letter(id, form_letter)
end