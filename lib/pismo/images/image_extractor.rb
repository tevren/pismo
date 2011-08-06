# This image extraction algorithm was ported (in part) from the one found in the Goose Library (https://github.com/tomazk/goose)

require 'fastimage'
require 'logger'

# 
# This image extractor will attempt to find the best image nearest the article.
# It uses the fastimage library to quickly check the dimensions of the image, and uses some simple hueristics to score images and pick the best one.
#
class ImageExtractor

  attr_reader :doc, :top_content_candidate, :bad_image_names_regex, :image, :url, :min_width, :min_height, :min_bytes, :max_bytes, :options, :logger

  def initialize(document, raw_document, url, is_homepage, options = {})
    @logger = Logger.new(STDOUT)

    # Change to DEBUG for full debugging output
    @logger.level = Logger::WARN

    @options = options
    @bad_image_names_regex = "\.html|\.ico|button|btn|twitter.jpg|facebook.jpg|digg.jpg|digg.png|delicious.png|facebook.png|reddit.jpg|doubleclick|diggthis|diggThis|adserver|/ads/|ec.atdmt.com|mediaplex.com|adsatt|view.atdmt|analytics|maps.google.com"
    @use_meta_image = false
    @meta_image = nil
    @meta_images = []
    @image = nil
    @images = []
    @raw_doc = raw_document
    @doc =  Nokogiri::HTML(document.raw_content, nil, 'utf-8')
    @url = url
    @top_content_candidate = document.content_at(0)
    @is_homepage = is_homepage

    @min_width = options[:min_width] || 100
    # Tall enough to make sure it's not a typical banner ad
    @min_height = options[:min_height] || 61
    @max_bytes = options[:max_bytes] || 300000
    @min_bytes = options[:min_bytes] || 5000
  end

  def getBestImages(limit = 3)
    @logger.debug("Starting to Look for the Most Relavent Images (min width: #{min_width}, min height: #{min_height})")
    search_content = @is_homepage ? @raw_doc : @top_content_candidate
    checkForMetaTags
    # Use meta image if there was a large enough one
    unless @use_meta_image
      checkForLargeImages(search_content, 0, 0)
    end

    # Use meta images if there were no content images found, even if meta images aren't large enough
    if @meta_image && !@image
      @image = @meta_image
      @images = @meta_images
    end

    @images = @images[0...limit].map{ |i|
      i.is_a?(String) ? i : buildImagePath(i.first['src'])
    }

    return @images
  end

  def getBestImage
    return getBestImages(1)
  end

  def checkForMetaTags
    return true if (checkForOpenGraphTag || checkForLinkTag)

    @logger.debug("unable to find meta image tag")
    return false
  end

  #  checks to see if we were able to find open graph tags on this page
  def checkForOpenGraphTag
    begin
      meta = @raw_doc.css("meta[property~='og:image']")

      meta.each do |item|
        next if (item["content"].length < 1)

        @logger.debug("Open Graph tag found")

        # Determine if meta image is large enough to use as the primary image (and don't look further)
        imageSource = buildImagePath(item["content"])
        valid_dimensions, width, height = areOKImageDimensions(imageSource)

        # Don't set the primary meta image if it's already been set
        unless @meta_image
          if valid_dimensions
              @logger.debug("Using Open Graph image as primary image")
              @use_meta_image = true
          end 
          @meta_image = imageSource
        end 
        @meta_images << @meta_image

        break
      end
    rescue
      @logger.debug "Error getting OG tag: #{$!}"
    end
    return @meta_image ? true : false
  end

  # checks to see if we were able to find link tags on this page
  def checkForLinkTag
    begin
      meta = @raw_doc.css("link[rel~='image_src']")
      meta.each do |item|
        next if (item["href"].length < 1) 

        @logger.debug("Open Graph tag found")

        # Determine if meta image is large enough to use as the primary image (and don't look further)
        imageSource = buildImagePath(item["href"])
        valid_dimensions, width, height = areOKImageDimensions(imageSource)

        # Don't set the primary meta image if it's already been set
        unless @meta_image
          if valid_dimensions
              @logger.debug("Using Open Graph image as primary image")
              @use_meta_image = true
          end 
          @meta_image = imageSource
        end 
        @meta_images << @meta_image

        break
      end
    rescue
      @logger.debug "Error getting link tag: #{$!}"
    end
    return @meta_image ? true : false
  end

  #  * 1. get a list of ALL images from the parent node
  #  * 2. filter out any bad image names that we know of (gifs, ads, etc..)
  #  * 3. do a head request on each file to make sure it meets our bare requirements
  #  * 4. any images left over, use fastimage to check their dimensions
  #  * 5. Score images based on different factors like relative height/width
  def checkForLargeImages(node, parentDepth, siblingDepth)
    images = []

    begin
      images = node.css("img")
    rescue
      @logger.debug "Ooops: #{$!}"
    end

    @logger.debug("checkForLargeImages: Checking for large images, found: " + images.size.to_s + " - parent depth: " + parentDepth.to_s + " sibling depth: " + siblingDepth.to_s)

    goodImages = filterBadNames(images)

    @logger.debug("checkForLargeImages: After filterBadNames we have: " + goodImages.size.to_s)

    goodImages = findImagesThatPassByteSizeTest(goodImages)

    @logger.debug("checkForLargeImages: After findImagesThatPassByteSizeTest we have: " + goodImages.size.to_s);

    imageResults = downloadImagesAndGetResults(goodImages, parentDepth)

    # pick out the image with the highest score

    highScoreImage = nil
    imageResults = imageResults.sort do |a,b|
      b[1] <=> a[1]
    end
    @images = imageResults

    highScoreImage = imageResults.first if imageResults.any?

    if (highScoreImage)
      @image = buildImagePath(highScoreImage.first["src"])
      @logger.debug("High Score Image is: " + @image)
    else
      @logger.debug("unable to find a large image, going to fall back mode. depth: " + parentDepth.to_s)

      if (parentDepth < 2)
        # // we start at the top node then recursively go up to siblings/parent/grandparent to find something good
        prevSibling = node.previous_sibling
        if (prevSibling)
          @logger.debug("About to do a check against the sibling element, class: " + (prevSibling["class"]||'none') + "' id: '" + (prevSibling["id"]||'none') + "'")
          siblingDepth = siblingDepth + 1
          checkForLargeImages(prevSibling, parentDepth, siblingDepth)
        else
          @logger.debug("no more sibling nodes found, time to roll up to parent node")
          parentDepth = parentDepth + 1
          checkForLargeImages(node.parent, parentDepth, siblingDepth)
        end
      end
    end
  end

  #  * takes a list of image elements and filters out the ones with bad names
  def filterBadNames(images)
    goodImages = []
    images.each do |image|
      if (isOkImageFileName(image))
        goodImages << image
      end
    end
    return goodImages
  end

  #  * check the image src against a list of bad image files we know of like buttons, etc...
  def isOkImageFileName(imageNode)
    return false if imageNode["src"].length.eql?(0)
    
    regexp = Regexp.new(bad_image_names_regex)
    if imageNode["src"].match(regexp)
      @logger.debug("Found bad filename for image: " + imageNode['src'])
      return false
    end
    
    return true
  end

  #  * Takes an image path and builds out the absolute path to that image
  #  * using the initial url we crawled so we can find a link to the image if they use relative urls like ../myimage.jpg
  def buildImagePath(image_src)
    newSrc = image_src.gsub(" ", "%20")
    if !newSrc.include?('http')
      newSrc = URI.join(url, newSrc).to_s
    end
    return newSrc
  end

  #  * loop through all the images and find the ones that have the sufficient bytes to even make them a candidate
  def findImagesThatPassByteSizeTest(images)
    cnt = 0

    goodImages = []
    images.each do |image|
      if (cnt > 10)
        @logger.debug("Abort! they have over 10 images near the top node: ")
        return goodImages
      end

      bytes = getBytesForImage(image["src"])

      bytes ||= 0

      if ((bytes == 0 || bytes > min_bytes) && bytes < max_bytes)
        cnt = cnt + 1

        @logger.debug("findImagesThatPassByteSizeTest: Found potential image - size: " + bytes.to_s + " src: " + image["src"] )
        goodImages << image
      else
        @logger.debug("File was too small or large: " + image["src"] + " - size: " + bytes.to_s + " src: " + image["src"] )
      end
    end
    return goodImages
  end

  #  * does the HTTP HEAD request to get the image bytes for this images
  def getBytesForImage(src)
    bytes = 0

    begin
      link = buildImagePath(src)
      link = link.gsub(" ", "%20")

      uri = URI.parse(link)
      req = Net::HTTP.new(uri.host, 80)
      resp = req.request_head(uri.path)

      bytes = min_bytes + 1

      currentBytes = resp.content_length
      
      contentType = resp.content_type;
      if (contentType.include?("image"))
        bytes = currentBytes
      end

    rescue
      @logger.debug "Error getting image size for #{src} - #{$!}"
    end

    return bytes
  end

  # * checks image dimensions to make sure they meet the requirements
  def areOKImageDimensions(image)
    ok_dimensions = true

    width, height = FastImage.size(image)

    width ||= 0
    height ||= 0

    if !width || !height
      @logger.debug("couldn't get image dimensions for " + image + ", skipping..")
      ok_dimensions = false
    end

    if (width < min_width || height < min_height)
      @logger.debug(image + " is too small (width: " + width.to_s + ", height: " + height.to_s + ") skipping..")
      ok_dimensions = false
    end

    return ok_dimensions, width, height
  end

  #  * Get real image dimensions using fastimage
  #  * we're going to score the images in the order in which they appear so images higher up will have more importance,
  #  * we'll count the area of the 1st image as a score of 1 and then calculate how much larger or small each image after it is
  #  * we'll also make sure to try and weed out banner type ad blocks that have big widths and small heights or vice versa
  #  * so if the image is 3rd found in the dom it's sequence score would be 1 / 3 = .33 * diff in area from the first image
  def downloadImagesAndGetResults(images, depthLevel)
    imageResults = []

    cnt = 1
    initialArea = 0

    images.each do |image|
      if (cnt > 5)
        @logger.debug("over 5 images attempted, that's enough for now")
        break
      end

      begin
        imageSource = buildImagePath(image["src"])

        valid_dimensions, width, height = areOKImageDimensions(imageSource)

        unless valid_dimensions
          next
        else
          sequenceScore = 1 / cnt.to_f
          area = width * height

          totalScore = 0
          if (initialArea == 0)
            initialArea = area
            totalScore = 1
          else
            # // let's see how many times larger this image is than the inital image
            areaDifference = area / initialArea
            totalScore = sequenceScore * areaDifference
            @logger.debug("Image stats: cnt: #{cnt}, areaDifference: #{areaDifference}, sequenceScore: #{sequenceScore}, totalScore: #{totalScore}")
          end

          @logger.debug(imageSource + " Area is: " + area.to_s + " sequence score: " + sequenceScore.to_s + " totalScore: " + totalScore.to_s)

          imageResults << [image, totalScore]

          if totalScore > 1
            @logger.debug("found an image with a score above 1; halt checking")

            break
          end

          cnt = cnt + 1
        end
      rescue
        @logger.debug "Error scoring image #{image['src']} - #{$!}"
      end
    end

    return imageResults
  end

end