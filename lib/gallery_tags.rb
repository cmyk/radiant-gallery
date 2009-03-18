module GalleryTags
  #tags available globally, not just on GalleryPages
  include Radiant::Taggable
  
  class GalleryTagError < StandardError; end
  
  tag "galleries" do |tag| 
    tag.expand
  end
  
  desc %{    
    Usage:
    <pre><code><r:galleries:each [order='order' by='by' limit='limit' offset='offset' level='top|current|bottom|all' keywwords='key1,key2,key3']>...</r:galleries:each></code></pre>
    Iterates through all galleries }
  tag "galleries:each" do |tag|
    content = ''
    options = {}
    options[:conditions] = {:hidden => false, :external => false}
    
    level = tag.attr['level'] ? tag.attr['level'] : 'all'
    raise GalleryTagError.new('Invalid value for attribute level. Valid values are: current, top, bottom') unless %[current top bottom all].include?(level)
    case level
    when 'current'
      options[:conditions][:parent_id] = if @current_gallery
        @current_gallery.id
      elsif self.base_gallery
        self.base_gallery
      else
        nil
      end
    when 'top'
      options[:conditions][:parent_id] = nil
    when 'bottom'
      options[:conditions][:children_count] = 0
    end
                                        
    if tag.attr['keywords']
      keywords = tag.attr['keywords'].split(',');     
      options[:joins] = :gallery_keywords  
      options[:conditions].merge!({"gallery_keywords.keyword" => keywords })
    end
    
    by = tag.attr['by'] ? tag.attr['by'] : "position"
    unless Gallery.columns.find{|c| c.name == by }
      raise GalleryTagError.new("`by' attribute of `each' tag must be set to a valid field name")
    end
    options[:limit] = tag.attr['limit'] ? tag.attr['limit'].to_i : 9999
    options[:offset] = tag.attr['offset'] ? tag.attr['offset'].to_i  : 0
    order = (%w[ASC DESC].include?(tag.attr['order'].to_s.upcase)) ? tag.attr['order'] : "ASC"
    options[:order] = "#{by} #{order}"  
    galleries = Gallery.find(:all, options)
    galleries.each do |gallery|
      tag.locals.gallery = gallery
      content << tag.expand
    end
    content
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery [id='id'] [name='name'] [keywords='key1, key2, key3']>...</r:gallery></code></pre>
    Selects current gallery }
  tag "gallery" do |tag|
    tag.locals.gallery = find_gallery(tag)
    tag.expand
  end
  
  tag 'gallery:if_current' do |tag|    
    tag.expand if @current_gallery
  end  
  
  tag 'gallery:unless_current' do |tag|    
    tag.expand unless @current_gallery
  end
  
  tag 'gallery:current' do |tag|    
    tag.locals.item = @current_gallery
    tag.expand
  end
    
  tag 'gallery:if_current_keywords' do |tag|    
    tag.expand if @current_keyword
  end  
  
  tag 'gallery:unless_current_keywords' do |tag|    
    tag.expand unless @current_keyword
  end
  
  tag 'gallery:current_keywords' do |tag|    
    @current_keyword
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery:name [safe='true']/></code></pre>
    Provides name for current gallery, safe is to make safe for web }
  tag "gallery:name" do |tag|
    gallery = tag.locals.gallery
    if tag.attr['safe']
      gallery.name = gallery.name.gsub(/[\s]+/, '_')
    end 
    gallery.name
  end
  
  desc %{                 
    Usage:
    <pre><code><r:gallery:keywords [separator=',']/></code></pre>
    Provides keywords for current and children galleries, use
    separator="separator_string" to specify the character between keywords }
  tag "gallery:keywords" do |tag|
    gallery = tag.locals.gallery    
    if tag.attr['separator']
      joiner = tag.attr['separator'] 
    else
      joiner=' '
    end
    gallery.keywords.gsub!(/\,/, joiner);
    tag.expand
  end                            

  desc %{
    Usage:
    <pre><code><r:gallery:keywords:each /></code></pre>
    Loops over each keywords for current and children galleries }
  tag "gallery:keywords:each" do |tag|
    content =''
    gallery = tag.locals.gallery
    gallery.gallery_keywords.uniq.each do |key|
      tag.locals.uniq_keywords = key
      content << tag.expand
    end
    content
  end 
  
  desc %{
    Usage:
    <pre><code><r:gallery:keywords:keyword/></code></pre>
    Get the keyword of the current gallery:keywords loop } 
  tag 'gallery:keywords:keyword' do |tag|
    gallery_keyword = tag.locals.uniq_keywords
    gallery_keyword.keyword 
  end
       
  desc %{
    Usage:
    <pre><code><r:gallery:keywords:link [*options]/></code></pre>
    Get the keyword and creates a link for the current gallery:keywords loop 
    options are rendered inline as key:value pairs i.e. class='' id='', etc.}    
  tag 'gallery:keywords:link' do |tag|
    keyword = tag.locals.uniq_keywords.keyword 
    options = tag.attr.dup
    attributes = options.inject('') { |s, (k, v)| s << %{#{k.downcase}="#{v}" } }.strip
    attributes = " #{attributes}" unless attributes.empty?
    text = tag.double? ? tag.expand : tag.render('name')  
    gallery_url = File.join(tag.render('url'))
    %{<a href="#{gallery_url[0..-2]}?keywords=#{keyword}"#{attributes}>#{keyword}</a>}
  end
  
  tag 'gallery:breadcrumbs' do |tag|
    gallery = find_gallery(tag)
    breadcrumbs = []
    gallery.ancestors_from(self.base_gallery_id).unshift(gallery).each do |ancestor|
      if @current_gallery == ancestor && @current_item.nil?
        breadcrumbs << %|#{ancestor.name}|
      else
        ancestor_absolute_url = File.join(tag.render('url'), ancestor.url(self.base_gallery_id))
        breadcrumbs.unshift(%|<a href="#{ancestor_absolute_url}">#{ancestor.name}</a>|)
      end
    end
    separator = tag.attr['separator'] || ' &gt; '
    breadcrumbs.join(separator)
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery:description /></code></pre>
    Provides description for current gallery }
  tag "gallery:description" do |tag|
    gallery = tag.locals.gallery
    gallery.description
  end  
  
  desc %{    
    Usage:
    <pre><code><r:gallery:children:each>...</r:gallery:children:each></code></pre>
    Iterates over all children in current gallery }
  tag "gallery:children:each" do |tag|
    content = ""
    gallery = find_gallery(tag)
    options = {}
    options[:conditions] = {:hidden => false, :external => false}
    by = tag.attr['by'] ? tag.attr['by'] : "position"
    unless Gallery.columns.find{|c| c.name == by }
      raise GalleryTagError.new("`by' attribute of `each' tag must be set to a valid field name")
    end
    options[:limit] = tag.attr['limit'] ? tag.attr['limit'].to_i : 9999
    options[:offset] = tag.attr['offset'] ? tag.attr['offset'].to_i  : 0
    order = (%w[ASC DESC].include?(tag.attr['order'].to_s.upcase)) ? tag.attr['order'] : "ASC"
    options[:order] = "#{by} #{order}"        
    gallery.children.find(:all, options).each do |sub_gallery| 
      tag.locals.gallery = sub_gallery
      content << tag.expand      
    end
    content
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery:if_children>...</r:gallery:if_children></code></pre> }
  tag "gallery:if_children" do |tag|
    gallery = find_gallery(tag)  
    tag.expand unless gallery.children.empty?
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery:unless_children>...</r:gallery:unless_children></code></pre> }
  tag "gallery:unless_children" do |tag|
    gallery = find_gallery(tag)  
    tag.expand if gallery.children.empty?
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery:if_galleries>...</r:gallery:if_galleries></code></pre> }
  tag "gallery:if_galleries" do |tag|
    gallery = find_gallery(tag)
    if gallery && !gallery.children.empty?
      tag.expand
    elsif gallery && gallery.children.empty?
      nil
    elsif Gallery.count(:conditions => {:parent_id => nil, :hidden => false})
      tag.expand
    end
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery:unless_galleries>...</r:gallery:unless_galleries></code></pre> }
  tag "gallery:unless_galleries" do |tag|
    gallery = find_gallery(tag)
    if gallery && gallery.children.empty?
      tag.expand
    elsif gallery && !gallery.children.empty?
      nil
    elsif Gallery.count(:conditions => {:parent_id => nil, :hidden => false})
      nil
    end
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery:if_items>...</r:gallery:if_items></code></pre> }
  tag "gallery:if_items" do |tag|
    gallery = find_gallery(tag)    
    tag.expand if gallery && !gallery.items.empty?
  end
  
  desc %{    
    Usage:
    <pre><code><r:gallery:unless_items>...</r:gallery:unless_items></code></pre> }
  tag "gallery:unless_items" do |tag|
    gallery = find_gallery(tag)  
    tag.expand if !gallery || gallery.items.empty?
  end
  
  desc %{
    Usage:
    <pre><code><r:gallery:children_size /></code></pre>
    Provides the number of children for current gallery }
  tag "gallery:children_size" do |tag|  
    gallery = find_gallery(tag)
    gallery.children.size    
  end
  
  desc %{
    Usage:
    <pre><code><r:gallery:items_size /></code></pre>
    Provides the number of items for current gallery }
  tag "gallery:items_size" do |tag|  
    gallery = find_gallery(tag)
    gallery.items.size    
  end
  

protected
  
  def find_gallery(tag)  
    if tag.locals.gallery
      tag.locals.gallery 
    elsif tag.attr["name"]
      Gallery.find_by_name tag.attr["name"]
    elsif tag.attr["id"]
      Gallery.find_by_id tag.attr["id"] 
    elsif @current_gallery
      @current_gallery
    elsif tag.locals.page.base_gallery
      tag.locals.page.base_gallery
    end
  end
  
end
