defmodule Stats.Events.Mock do
  @moduledoc false
  alias Stats.Events

  def add_utm_parameters(event) do
    {utm_source, utm_medium, utm_campaign, utm_term, utm_content} = Enum.random(utm_parameters())

    Map.merge(event, %{
      utm_source: utm_source,
      utm_medium: utm_medium,
      utm_campaign: utm_campaign,
      utm_term: utm_term,
      utm_content: utm_content
    })
  end

  defp utm_parameters do
    [
      {"google", "ppc", "spring_sale", "running+shoes", "logolink"},
      {"facebook", "social", "black_friday", nil, "carousel_ad"},
      {"instagram", "social", "holiday_promo", "gift+ideas", "story_ad"},
      {"twitter", "organic", nil, nil, "tweet_link"},
      {"linkedin", "email", "b2b_offer", nil, "cta_button"},
      {"tiktok", "ppc", "summer_discount", "sneakers", nil},
      {"youtube", "video", "new_product_launch", nil, "preroll_ad"},
      {"pinterest", "social", "wedding_ideas", "bridal+dresses", "pin_image"},
      {"snapchat", "social", "flash_sale_weekend", nil, "story_swipeup"},
      {"reddit", "ppc", "tech_deals", "gaming+laptop", "sidebar_ad"},
      {"bing", "search", "cyber_monday", "laptop+deals", "headline_ad"},
      {"medium", "referral", "content_marketing_q1", nil, "article_link"},
      {"quora", "referral", "webinar_signup", "marketing+automation", nil},
      {"amazon", "ppc", "prime_day", "wireless+earbuds", "sponsored_product"},
      {"yahoo", "email", "exclusive_offer", nil, "newsletter_banner"},
      {"ebay", "ppc", "electronics_discount", "gaming+mouse", "sponsored_listing"},
      {"duckduckgo", "search", "privacy_campaign", "vpn+subscription", "top_ad"},
      {"tumblr", "social", "art_showcase", "digital+illustration", "featured_post"},
      {"spotify", "audio", "music_promo", nil, "podcast_ad"},
      {"apple", "app_store", "ios_launch", nil, "featured_banner"},
      {"playstore", "app_store", "android_promo", nil, "editor_choice"},
      {"discord", "social", "community_growth", nil, "server_invite"},
      {"twitch", "video", "gaming_sponsorship", "esports+tournament", "stream_overlay"},
      {"telegram", "social", "crypto_airdrop", nil, "pinned_message"},
      {"whatsapp", "messaging", "direct_promo", nil, "group_invite"},
      {"wechat", "messaging", "chinese_market_expansion", nil, "qr_code"},
      {"vimeo", "video", "film_promotion", nil, "homepage_banner"},
      {"kickstarter", "crowdfunding", "startup_funding", nil, "project_page"},
      {"producthunt", "referral", "new_app_launch", nil, "featured_post"},
      {"groupon", "deals", "local_discounts", "spa+package", "highlighted_offer"},
      {"airbnb", "referral", "travel_discount", "beach+house", "recommendation"},
      {"expedia", "ppc", "vacation_sale", "flights+to+london", "top_banner"},
      {"tripadvisor", "referral", "hotel_review_promo", "best+hotels+paris", "featured_review"},
      {"nike", "social", "athlete_collab", "running+shoes", "instagram_story"},
      {"adidas", "email", "exclusive_sneaker_drop", nil, "newsletter_cta"},
      {"hulu", "video", "tv_show_promo", "new+season", "pre_roll_ad"},
      {"netflix", "email", "free_trial_reminder", nil, "cta_button"},
      {"hbo", "ppc", "movie_promo", "action+thrillers", "display_ad"},
      {"disney", "social", "new_theme_park_ride", nil, "facebook_video"},
      {"tesla", "referral", "model_3_promo", nil, "influencer_review"},
      {"spaceX", "ppc", "mars_colonization", nil, "search_ad"},
      {"starbucks", "email", "loyalty_rewards", nil, "cta_button"},
      {"mcdonalds", "social", "limited_edition_burger", nil, "tiktok_video"},
      {"uber", "referral", "driver_signup_bonus", nil, "promo_code"},
      {"lyft", "ppc", "ride_credit_offer", "cheap+rides", "search_ad"},
      {"doordash", "email", "free_delivery_week", nil, "cta_button"},
      {"grubhub", "ppc", "pizza_discount", "order+pizza", "banner_ad"},
      {"zoom", "referral", "business_plan_promo", nil, "linkedin_post"},
      {"slack", "email", "workspace_invite", nil, "cta_button"},
      {"notion", "referral", "productivity_promo", nil, "youtube_sponsorship"},
      {"github", "organic", "open_source_promo", nil, "repository_readme"},
      {"gitlab", "ppc", "devops_tool", "ci+cd", "google_ad"},
      {"stackoverflow", "referral", "developer_survey", nil, "footer_link"},
      {"coursera", "ppc", "online_course_discount", "python+course", "search_ad"},
      {"udemy", "email", "50_percent_off", nil, "cta_button"},
      {"khanacademy", "organic", "free_education_campaign", nil, "blog_post"},
      {"duolingo", "social", "language_learning_promo", nil, "instagram_carousel"},
      {"wikipedia", "referral", "fundraising_drive", nil, "header_banner"},
      {"tinder", "ppc", "premium_membership_promo", nil, "facebook_ad"},
      {"bumble", "social", "valentines_day_special", nil, "tiktok_ad"},
      {"onlyfans", "referral", "creator_promo", nil, "exclusive_content"},
      {"patreon", "email", "support_creators_campaign", nil, "cta_button"},
      {"substack", "referral", "newsletter_promotion", nil, "recommendation"},
      {"robinhood", "ppc", "stock_trading_signup", "free+stocks", "banner_ad"},
      {"coinbase", "referral", "crypto_signup_bonus", "bitcoin", "signup_cta"},
      {"binance", "ppc", "crypto_trading_discount", nil, "display_ad"},
      {"opensea", "referral", "nft_launch", "digital+art", "artist_promo"},
      {"kick", "video", "streamer_partnership", nil, "homepage_feature"},
      {"rumble", "video", "alt_media_campaign", nil, "recommendation"},
      {"yelp", "ppc", "local_restaurant_promo", "best+pizza", "sponsored_listing"},
      {"zillow", "ppc", "real_estate_deals", "buy+house", "search_ad"},
      {"realtor", "organic", "home_search_promo", "apartments+near+me", "sidebar_ad"},
      {nil, nil, nil, nil, nil},
      {nil, nil, nil, nil, nil},
      {nil, nil, nil, nil, nil},
      {nil, nil, nil, nil, nil}
    ]
  end

  def add_country_details(event) do
    Events.country_details(event, generate_ipv4())
  end

  defp generate_ipv4 do
    Enum.map_join(1..4, ".", fn _ -> :rand.uniform(255) end)
  end

  def add_os_and_browser_details(event) do
    ua = random_ua()

    event
    |> Map.replace(:operating_system, ua.os.name)
    |> Map.replace(:operating_system_version, ua.os.version)
    |> Map.replace(:browser, ua.browser_family)
    |> Map.replace(:browser_version, ua.client.version)
  end

  defp random_ua, do: user_agents() |> Enum.random() |> UAInspector.parse()

  defp user_agents do
    [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.3",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1.1 Safari/605.1.1",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.1",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 Edg/128.0.0.",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.",
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.3",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1.1 Mobile/15E148 Safari/604.",
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/27.0 Chrome/125.0.0.0 Mobile Safari/537.3",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/132.0.6834.100 Mobile/15E148 Safari/604.",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604."
    ]
  end
end
