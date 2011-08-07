require 'helper'

class TestTitle < Test::Unit::TestCase

	def test_cnn
		@doc = Pismo.document('http://www.cnn.com/2010/POLITICS/08/13/democrats.social.security/index.html')
		title = 'Democrats to use Social Security against GOP this fall - CNN.com'
		assert_equal title, @doc.title
	end

	def test_huffinton
		@doc = Pismo.document('http://www.huffingtonpost.com/2010/08/13/federal-reserve-pursuing_n_681540.html')
		assert_equal "Federal Reserve's Low Rate Policy Is A 'Dangerous Gamble,' Says Top Central Bank Official", @doc.title
	end
	
	def test_techcrunch 
		@doc = Pismo.document("http://techcrunch.com/2010/08/13/gantto-takes-on-microsoft-project-with-web-based-project-management-application/")
		assert_equal "TechCrunch | Gantto Takes On Microsoft Project With Web-Based Project Management Application", @doc.title
	end
		
	def test_guardiantech
		@doc = Pismo.document("http://www.guardian.co.uk/technology/2011/aug/06/randi-zuckerberg-facebook-social-networking")
		assert_equal "Mark Zuckerberg's sister Randi quits Facebook to set up on her own", @doc.title
	end
	
	def test_businessweek
		@doc = Pismo.document("http://www.businessweek.com/magazine/content/10_34/b4192066630779.htm")
		assert_equal "Olivia Munn: Queen of the Uncool", @doc.title		
	end
	
	def test_foxnews
		@doc = Pismo.document("http://www.foxnews.com/politics/2010/08/14/russias-nuclear-help-iran-stirs-questions-improved-relations/")
		title = "Russia's Nuclear Help to Iran Stirs Questions About Its 'Improved' Relations With U.S."
		assert_equal title, @doc.title
	end
	
	def test_aol
		@doc = Pismo.document("http://www.aolnews.com/nation/article/the-few-the-proud-the-marines-getting-a-makeover/19592478")
		title = "The Few. The Proud. The  Marines ... Getting a Makeover?"
		assert_equal title, @doc.title
	end
	
	def test_wallstreetjournal
		@doc = Pismo.document("http://online.wsj.com/article/SB10001424052748704532204575397061414483040.html")
		title = "Slow Progress on Some Big Stimulus Projects"
		assert_equal title, @doc.title
	end
	
	def test_usatoday
		@doc = Pismo.document("http://content.usatoday.com/communities/thehuddle/post/2010/08/brett-favre-practices-set-to-speak-about-return-to-minnesota-vikings/1")
		title = "Brett Favre says he couldn't give up on one more chance to win the Super Bowl with Vikings - The Huddle - USATODAY.com"
		assert_equal title, @doc.title		
	end
	
	def test_espn
		@doc = Pismo.document("http://sports.espn.go.com/espn/commentary/news/story?id=5461430")
		title = "Hill: Meyer, Saban grandstanding about agents"
		assert_equal title, @doc.title		
	end
		
	def test_washington_post
		@doc = Pismo.document("http://www.washingtonpost.com/wp-dyn/content/article/2010/12/08/AR2010120803185.html")
		title = "High court torn on Ariz. law to punish companies for hiring illegal immigrants"
		assert_equal title, @doc.title		
	end
	
	def test_nytimes
		@doc = Pismo.document("http://www.nytimes.com/2011/08/07/business/pret-a-manger-with-new-fast-food-ideas-gains-a-foothold-in-united-states.html?_r=2&pagewanted=all")
		title = "Pret A Manger, With New Fast-Food Ideas, Gains a Foothold in United States"
		assert_equal title, @doc.title
	end		
	
	def test_bbcnews
		@doc = Pismo.document("http://www.bbc.co.uk/news/world-us-canada-14428730")
		title = "US man charged over Facebook spam"
		assert_equal title, @doc.title		
	end
	

end