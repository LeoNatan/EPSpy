cask "epspy" do
  version :latest
  sha256 :no_check
  def get_url
    assets = GitHub.get_latest_release("LeoNatan", "EPSpy").fetch("assets")
    latest = assets.find{|a| a["name"] == "EPSpy.zip" }.fetch("browser_download_url")
	latest
  end
  url get_url

  app "EPSpy.app"
end