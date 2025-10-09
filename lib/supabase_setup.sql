-- Создание таблицы для финансовых предложений
CREATE TABLE financial_offers (
  id SERIAL PRIMARY KEY,
  logo TEXT, -- Логотип в формате base64
  brand TEXT NOT NULL, -- Бренд
  label TEXT NOT NULL, -- Ярлык
  amount_up NUMERIC NOT NULL, -- Сумма до
  term TEXT NOT NULL, -- Срок
  age TEXT NOT NULL, -- Возраст
  button_link TEXT NOT NULL, -- Ссылка на кнопку
  advertisement TEXT NOT NULL, -- Реклама
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Создание политик доступа для публичного доступа (для упрощения примера)
-- В реальном приложении настройте политики безопасности более тщательно

-- Разрешить анонимное чтение всех записей
CREATE POLICY "Allow public read" ON financial_offers
  FOR SELECT USING (true);

-- Разрешить анонимное создание записей
CREATE POLICY "Allow public insert" ON financial_offers
  FOR INSERT WITH CHECK (true);

-- Разрешить анонимное обновление записей
CREATE POLICY "Allow public update" ON financial_offers
  FOR UPDATE USING (true);

-- Разрешить анонимное удаление записей
CREATE POLICY "Allow public delete" ON financial_offers
  FOR DELETE USING (true);

-- Включить RLS (Row Level Security)
ALTER TABLE financial_offers ENABLE ROW LEVEL SECURITY;