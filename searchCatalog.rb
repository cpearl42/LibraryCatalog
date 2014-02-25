require 'rubygems'
require 'nokogiri'  
require 'open-uri'

####################################################################
# Given a book title, do an HTTP request to the San Mateo County
# Library catalog, and get the book's record number(s)
# It also checks to make sure the book has the same author as the
# requested book
def getRecordNumbers(book, author)
    
    # Build search query for San Mateo County Library, English,
    # books or eBooks only, SMC only
    searchURL = "http://www.smcl.org/en/catalog/search/title/"
    searchURL += book + "?search_format=a|z&search_langs=eng&location=any&perpage=120"

    #searchURL = "DaVinciCode.html"
    searchURL = URI.escape(searchURL)
    
    # Make the HTTP request
    puts "Looking up " + book + "...."
    page = Nokogiri::HTML(open(searchURL))   
        
    # Get records inside div class hitlist-item
    links = page.css("div.hitlist-item")
    
    records = Array.new
    
    if links.empty?
        puts "No record found for: '" + book + "' by '" + author + "'"
        return records
    end
    
    # For each record, extract the book title, author, and record number.
    # It's possible the book title is a close enough match, but wrong
    # author... we don't want those.
    links.each{|link|
        titleLink = link.css("div.hitlist-title strong") # HTML
        title = titleLink.text
        
        titleLink = titleLink.css('a').to_s  # HTML, which has record #
        if titleLink.match('record') 
            recNum = titleLink.split('record/')[-1]
            recNum = recNum.split('"')[0]
        end     
        
        recAuthor = link.css("ul.hitlist-info li a")[0].text
        if (recAuthor.downcase).match(author)  # Is requested author a match?
            #puts "Author match: " + author + "    " + recAuthor 
            #authorMatch = true
            record = Array.new
            record << title << author << recNum
            records << record
        else
            #puts "Author does not match: " + author + "    (catalog) " + recAuthor 
        end  
    }
    
    if records.empty?
        puts "No titles had the right author for:  '" + book + "'  by '" + author + "'"
    end
    
    return records
end

####################################################################
# Given a book's record number, hit the catalog to get the
# book's locations
def findLocations(book, author, recNum)
    
    # Build query based on record number
    recordURL = "http://www.smcl.org/en/catalog/record/"
    recordURL += recNum + "#location"
    #recordURL = recNum + "BookLocations.html"
    recordURL = URI.escape(recordURL)
    
    # Make the HTTP request
    #puts "Getting book record...."
    page = Nokogiri::HTML(open(recordURL))   
    
    # From each record, get the location, etc.
    page.css("div.item-avail-disp tr").each do |record|
 
        location = record.css('td')[0]

        if location != nil
            location = location.text
            callNum = record.css('td')[1].text
            status = record.css('td')[2].text
    
            recordTemp = Array.new
            recordTemp << book << author << location << callNum << status
  
            # Add book info to main list
            @recordList << recordTemp
        end
    end
        
end

####################################################################
# Prints out book locations
# Title, Author, Location, Call Number, Status
def printBooks()
    #puts @recordList
    
    belmontAvailable = Array.new
    sanCarlosAvailable = Array.new
    belmontNotAvailable = Array.new
    otherLocations = Array.new
    
    # Sort records
    @recordList.each do |record|
        if record[2].include?('Belmont') 
            if record[4].include?('Available')
                belmontAvailable << record
            else
                belmontNotAvailable << record
            end
        elsif record[2].include?('San Carlos')
            if record[4].include?('Available')
                sanCarlosAvailable << record
            end
        else
            otherLocations << record
        end
            
    end
    
    # Belmont available first
    if !belmontAvailable.empty?
        puts "\n\nBelmont Available" 
        puts "----------------------------------------"
        belmontAvailable.sort_by! { |book| book[0] }  # Sort by book title

        belmontAvailable.each do |book|
            puts book[0] + "   " + book[1] + "    " + book[3]
        end
    end
    
    # San Carlos available
    if !sanCarlosAvailable.empty?
        puts "\n\nSan Carlos Available" 
        puts "----------------------------------------"
        sanCarlosAvailable.sort_by! { |book| book[0] }  # Sort by book title

        sanCarlosAvailable.each do |book|
            puts book[0] + "   " + book[1] + "    " + book[3]
        end
    end
    
    # Belmont but not available
    if !belmontNotAvailable.empty?
        puts "\n\nBelmont, But Not Available" 
        puts "----------------------------------------"
        belmontNotAvailable.sort_by! { |book| book[0] }  # Sort by book title

        belmontNotAvailable.each do |book|
            puts book[0] + "   " + book[1] + "    " + book[3] + "    " + book[4]
        end
    end
    
    # Everything else
    if !otherLocations.empty? && !@belmontSCOnly
        puts "\n\Other Libraries" 
        puts "----------------------------------------"
        otherLocations.sort_by! { |book| book[0] }  # Sort by book title

        otherLocations.each do |book|
            puts book[0] + "   " + book[1] + "    "+ book[2] + "    " + book[3]
        end
    end
end

####################################################################
# Tidies up book title; cuts off at : or (, to have more liklihood
# of a match with library catlog.
def processTitle(title)
    # Split at : or (
    title = title.split(":")[0]
    title = title.split("(")[0]
   
    title.gsub!(/[^0-9A-Za-z\-\s]/, '') # Strip special chars
    title.strip!
    
    # Make all lower case
    return title.downcase
end

####################################################################
# Tidies up book author; gets rid of "by", makes lower case; 
# cuts off if there is a comma, etc.
def processAuthor(author)
    # Get rid of "by"
    author.gsub!(" by ", "")
    
    # Replace any .s, because catalog doesn't have them
    author.gsub!(".", "")
    
    # Split at , if there is one
    author = author.split(",")[0]
    author = author.split("(")[0]
    author.strip!
    
    # Make all lower case
    return author.downcase
end

####################################################################
# Gets my Amazon Wish List, return array with book titles / authors
def getAmazonWishList(wishListURL)
    bookList = Array.new
    
    # Make the HTTP request
    puts "Getting Amazon wish list...."
    page = Nokogiri::HTML(open(wishListURL))
    
    books = page.css('tr')   # Book list enclosed in <tr> tag
    
    books.each do |book|
        title = book.css('strong a').text
        if title != ""
            title = processTitle(title)
            author = processAuthor(book.css('span.tiny')[0].text)
            
            book = Array.new
            book << title << author
            bookList << book
        end
    end
    
    return bookList
end

####################################################################
# Main function.  Pass in the name of the book, it grabs the
# book's record numbers, then looks up the locations
def findBooks(book, author)
    
    # Look up the book's record number(s) in the catalog
    recordNumbers = Array.new
    recordNumbers = getRecordNumbers(book, author)
    
    if !recordNumbers.empty?
        # For each record number, send request to get locations
        recordNumbers.each do |recNum|
            title = recNum[0]
            author = recNum[1]
            recNum = recNum[2]
            findLocations(book, author, recNum)
        end
    end
    
end

@belmontSCOnly = false
@recordList = Array.new

title = ARGV[0]
author = ARGV[1]
if title == "BELMONT" # No book name provided; use Amazon Wish List
    @belmontSCOnly = true
    title = nil
end
if ARGV[2] == "BELMONT"
    @belmontSCOnly = true
end


if title == nil  # No specific book, use wish list
    wishListPage1URL = "http://www.amazon.com/registry/wishlist/V5GOTGQV5XBK/ref=cm_wl_sb_v?reveal=unpurchased&filter=3&sort=date-added&layout=compact&x=5&y=12"
    wishListPage2URL = "http://www.amazon.com/registry/wishlist/V5GOTGQV5XBK/ref=cm_wl_sortbar_v_page_2?_encoding=UTF8&filter=3&layout=compact&page=2&reveal=unpurchased&sort=date-added"
    
    #wishListLocalURL = "AmazonWishList.html"
    
    bookList = Array.new
    #bookList2 = Array.new
    #bookList = getAmazonWishList(wishListLocalURL)
   
    #bookList = getAmazonWishList(wishListPage2URL)
    #puts "Getting wishlist 2..."
    #bookList2 = getAmazonWishList(wishListLocalURL)
    
    #bookList = bookList.concat bookList2
    
    File.open("AmazonWishList.txt") do |fp|
        fp.each do |line|
            line = line.chomp.split("\t")
            book = line[0]
            author = line[1]
            info = Array.new
            info << book << author
            bookList << info
         end
       end
       
    bookList.each do |book|
        title = book[0]
        author = book[1]
        
        #print "Title: " 
        #puts title
        #print "Author:  "
        #puts author
        #stuff = title + "\t" + author + "\n"
        #File.open("AmazonWishList.txt", 'a') { |file| file.write(stuff) }
        findBooks(title, author)
        sleep(10)
    end
  
    printBooks()
else
    findBooks(title, author)
    printBooks()
end

exit


#################################
# Old code
@recordList = Array.new
bookList = Array.new

# Testing books
book = Array.new
book << "Da Vinci Code" << "Dan Brown" << "1285476"
bookList << book
book = Array.new
book << "Caliban's War" << "James S A Corey" << "2139702"
bookList << book
book = Array.new
book << "The Grapes of Wrath" << "John Steinbeck" << "1533554"
bookList << book
book = Array.new
book << "Lean-In" << "Sheryl Sandberg" << "2172164"
bookList << book

#findBooks(bookTitle, author)

#getRecordNumbers("The Da Vinci Code", "Dan Brown")

bookList.each do |book|
    puts "Book name: " + book[0] + "   Book record: " + book[1]
    findLocations(book[0], book[1], book[2])
   
end

printBooks()

# TO DO
# Add a "book not found", either no records found, OR, 0 authors match

