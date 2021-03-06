require 'git_support'

class TC_Resource < Test::Unit::TestCase
  include GitSupport

  def test_path_check
    assert_raise Wiki::MultiError do
      Wiki::Resource.find(@repo, '#invalid#')
    end
    assert_raise Wiki::MultiError do
      Wiki::Resource.find(@repo, ' spaces ')
    end
    assert_nil Wiki::Resource.find(@repo, 'spaces in the path')
  end

  def test_find
    assert_instance_of Wiki::Tree, Wiki::Resource.find(@repo, '')
    assert_instance_of Wiki::Tree, Wiki::Tree.find(@repo, '')
    assert_nil Wiki::Page.find(@repo, '')

    assert_instance_of Wiki::Tree, Wiki::Resource.find(@repo, '/')
    assert_instance_of Wiki::Tree, Wiki::Tree.find(@repo, '/')
    assert_nil Wiki::Page.find(@repo, '/')

    assert_instance_of Wiki::Page, Wiki::Resource.find(@repo, 'Home')
    assert_nil Wiki::Tree.find(@repo, 'Home')
    assert_instance_of Wiki::Page, Wiki::Page.find(@repo, 'Home')

    assert_instance_of Wiki::Tree, Wiki::Resource.find(@repo, '/')
    assert_instance_of Wiki::Tree, Wiki::Tree.find(@repo, '/')
    assert_nil Wiki::Page.find(@repo, '/')

    assert_instance_of Wiki::Tree, Wiki::Resource.find(@repo, '/root')
    assert_instance_of Wiki::Tree, Wiki::Tree.find(@repo, '/root')
    assert_nil Wiki::Page.find(@repo, '/root')
  end

  def test_find!
    assert_instance_of Wiki::Tree, Wiki::Resource.find!(@repo, '/root')
    assert_instance_of Wiki::Tree, Wiki::Tree.find!(@repo, '/root')
    assert_raise Wiki::Resource::NotFound do
      Wiki::Page.find!(@repo, '/root')
    end

    assert_instance_of Wiki::Page, Wiki::Resource.find!(@repo, '/Home')
    assert_instance_of Wiki::Page, Wiki::Page.find!(@repo, '/Home')
    assert_raise Wiki::Resource::NotFound do
      Wiki::Tree.find!(@repo, '/Home')
    end

    assert_raise Wiki::Resource::NotFound do
      Wiki::Resource.find!(@repo, '/foo')
    end
    assert_raise Wiki::Resource::NotFound do
      Wiki::Page.find!(@repo, '/foo')
    end
    assert_raise Wiki::Resource::NotFound do
      Wiki::Tree.find!(@repo, '/foo')
    end
  end

  def test_new?
    assert !Wiki::Page.find(@repo, 'Home').new?
    assert !Wiki::Tree.find(@repo, '').new?
    assert Wiki::Page.new(@repo, 'new').new?
    assert Wiki::Tree.new(@repo, 'new').new?
  end

  def test_type
    assert Wiki::Page.find(@repo, 'Home').page?
    assert Wiki::Tree.find(@repo, '').tree?
  end

  def test_name
    assert_equal 'name.ext', Wiki::Resource.new(@repo, '/path/name.ext').name
  end

  def test_title
    assert_equal 'name', Wiki::Resource.new(@repo, '/path/name.ext').title
  end

  def test_path
    assert_equal 'path/name.ext', Wiki::Resource.new(@repo, '/path/name.ext').path
  end

  def test_safe_name
    assert_equal '0_1_2_3_4_5', Wiki::Resource.new(@repo, '0 1 2 3 4 5').safe_name
  end
end
