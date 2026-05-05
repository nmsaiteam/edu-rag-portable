-- EDU RAG: Создание функции поиска для pgvector
-- Запустите ЭТУ команду ОДИН РАЗ перед импортом workflow:
--
-- PowerShell:
-- docker exec -i pg-rag psql -U rag -d ragdb -f /dev/stdin < setup_search_function.sql
--
-- Или скопируйте содержимое и выполните через psql / pgAdmin

CREATE OR REPLACE FUNCTION search_chunks(
  query_vec text,
  filter_subject text DEFAULT NULL,
  filter_grade int DEFAULT NULL,
  result_limit int DEFAULT 5
)
RETURNS TABLE(
  id int,
  subject text,
  grade int,
  book_id text,
  title text,
  content text,
  similarity double precision
) AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.subject::text, c.grade, c.book_id::text, c.title::text, c.content::text,
    (1 - (c.embedding <=> query_vec::vector))::double precision as similarity
  FROM rag_chunks c
  WHERE (filter_subject IS NULL OR c.subject = filter_subject)
    AND (filter_grade IS NULL OR c.grade = filter_grade)
  ORDER BY c.embedding <=> query_vec::vector
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;
