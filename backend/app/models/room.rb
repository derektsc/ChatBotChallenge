class Room < ApplicationRecord
    # Relacionamentos:
    # Uma sala tem muitas mensagens
    has_many :messages, dependent: :destroy
    
    # Validações
    validates :title, presence: true
    validates :channel_name, presence: true, uniqueness: true
    validates :status, inclusion: { in: %w[open closed] }

    # Callback: gera um channel_name único antes de criar a sala
    # O channel_name será usado pelo ActionCable para identificar a sala
    before_validation :generate_channel_name, on: :create

    # Scope: retorna apenas salas abertas
    scope :open, -> { where(status: 'open') }
    
    # Scope: retorna apenas salas fechadas
    scope :closed, -> { where(status: 'closed') }

    private

    # Gera um channel_name único baseado em um UUID
    # Exemplo: "room_550e8400-e29b-41d4-a716-446655440000"
    def generate_channel_name
        self.channel_name ||= "room_#{SecureRandom.uuid}"
    end
end
