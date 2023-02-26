require 'sqlite3'

class TumblrDatabase
  def initialize(database_name)
    @db = SQLite3::Database.new(database_name)
    create_tables
  end
  
  def create_tables
    # create the tumblr_master table
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS tumblr_master (
        post_id INTEGER PRIMARY KEY,
        member_name TEXT,
        created_date TEXT,
        post_type TEXT
      );
    SQL
    
    # create the tumblr_image table
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS tumblr_image (
        post_id INTEGER PRIMARY KEY,
        member_name TEXT,
        save_name TEXT,
        created_date TEXT
      );
    SQL
    
    # create the tumblr_video table
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS tumblr_video (
        post_id INTEGER PRIMARY KEY,
        member_name TEXT,
        save_name TEXT,
        created_date TEXT
      );
    SQL
  end
  
  def insert_tumblr_master(post_id, member_name, created_date, type)
    @db.execute("INSERT INTO tumblr_master (post_id, member_name, created_date, type) VALUES (?, ?, ?, ?)", post_id, member_name, created_date, type)
  end
  
  def insert_tumblr_image(post_id, member_name, save_name, created_date)
    @db.execute("INSERT INTO tumblr_image (post_id, member_name, save_name, created_date) VALUES (?, ?, ?, ?)", post_id, member_name, save_name, created_date)
  end
  
  def insert_tumblr_video(post_id, member_name, save_name, created_date)
    @db.execute("INSERT INTO tumblr_video (post_id, member_name, save_name, created_date) VALUES (?, ?, ?, ?)", post_id, member_name, save_name, created_date)
  end
  
  def update_tumblr_master(post_id, member_name, created_date, type)
    @db.execute("UPDATE tumblr_master SET member_name = ?, created_date = ?, type = ? WHERE post_id = ?", member_name, created_date, type, post_id)
  end
  
  def update_tumblr_image(post_id, member_name, save_name, created_date)
    @db.execute("UPDATE tumblr_image SET member_name = ?, save_name = ?, created_date = ? WHERE post_id = ?", member_name, save_name, created_date, post_id)
  end
  
  def update_tumblr_video(post_id, member_name, save_name, created_date)
    @db.execute("UPDATE tumblr_video SET member_name = ?, save_name = ?, created_date = ? WHERE post_id = ?", member_name, save_name, created_date, post_id)
  end
end
