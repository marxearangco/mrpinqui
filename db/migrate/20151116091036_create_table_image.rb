class CreateTableImage < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.integer :code
      t.attachment :photo
      t.timestamps
    end
  end
end
