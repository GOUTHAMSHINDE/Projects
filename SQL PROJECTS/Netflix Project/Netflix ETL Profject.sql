--create database Netflixdb
use Netflixdb;

drop table if exists netflix;
create table netflix
(
show_id varchar(10) primary key,
type varchar(10),
title nvarchar(200),
director varchar(250),
cast varchar(1000),
country varchar(150),
date_added date,
release_year int,
rating varchar(10),
duration varchar(12),
listed_in varchar(100),
description varchar(500)
)

/*alter table netflix
add primary key(show_id)*/


-- Lets create another table to perform data cleaning.
drop table if exists netflix_new
select * 
into netflix_new
from netflix
select * from netflix_new
-- 1) Removing duplicates

select * from Netflix_new where concat(title,type) in --Total we have 3 duplicates
(select concat(title,type)
from netflix_new
group by concat(title,type)
having COUNT(*)>1) 
order by title

with cte as( 
	select title,type, ROW_NUMBER()over(partition by title,type order by show_id) as rn
	from netflix_new )
delete from cte 
where rn>1

-- 2) let's create new table for director,genre,cast and country.

select show_id, trim(value) as director
into nf_director
from netflix_new
cross apply string_split(director,',')

select * from nf_director

select show_id, trim(value) as genre
into nf_genre
from netflix_new
cross apply string_split(listed_in,',')

select * from nf_genre

select show_id, trim(value) as cast
into nf_cast
from netflix_new
cross apply string_split(cast,',')

select show_id, trim(value) as country
into nf_country
from netflix_new
cross apply string_split(country,',')

select * from nf_cast;
select * from nf_country;


-- 3) Handling Null values

select * from netflix_new where country is null

insert into nf_country
select show_id,m.country
from Netflix_new n
inner join(
	select director,country
	from nf_director d
	inner join nf_country c
	on d.show_id=c.show_id
	group by director,country
	) m
on n.director=m.director
where n.country is null

update netflix_new 
set netflix_new.country=nf_country.country
from netflix_new 
inner join nf_country 
on netflix_new.show_id=nf_country.show_id
where netflix_new.country is null


select * from netflix_new -- Data are placed in rating instead of duration.
where duration is null

update netflix_new
set duration= rating
where duration is null

select *
from netflix_new
where title='13TH: A Conversation with Oprah Winfrey & Ava DuVernay'

update netflix_new
set rating= case 
				when title='13TH: A Conversation with Oprah Winfrey & Ava DuVernay' then 'TV-MA'
				when title='Gargantia on the Verdurous Planet' then 'TV-14'
				when title='Little Lunch' then 'TV-PG'
				when title='My Honor Was Loyalty' then 'TV-MA'
				END
where rating is null

-- Data Analysis
/*1  for each director count the no of movies and tv shows created by them in separate columns 
for directors who have created tv shows and movies both */

select d.director, COUNT(case when type='movie' then d.show_id end) as Movies, COUNT(case when type='tv show' then d.show_id end) as tvshows
from nf_director d
inner join netflix_new n
on d.show_id=n.show_id
group by d.director
having COUNT(distinct type)>1
order by director

--2 which country has highest number of comedy movies 
--select distinct genre from nf_genre;
select top 1 c.country, COUNT(distinct c.show_id) as country_cnt 
from nf_country c
inner join nf_genre g
on c.show_id=g.show_id
inner join netflix_new n
on c.show_id=n.show_id
where type='movie' and genre = 'comedies'
group by c.country
order by country_cnt desc

--3 for each year (as per date added to netflix), which director has maximum number of movies released

with cte as(select d.director, year(date_added)as year_released, COUNT(d.show_id) as count_of_movies,
DENSE_RANK()over(partition by year(date_added) order by COUNT(d.show_id) desc, d.director) as rn
from nf_director d
inner join netflix_new n
on d.show_id=n.show_id
where n.type='movie'
group by d.director,YEAR(date_added))
select director, year_released, count_of_movies
from cte where rn=1

--4 what is average duration of movies in each genre
select genre, avg(cast(SUBSTRING(duration,1,CHARINDEX(' ',duration))As int))  avg_duration -- alternatively replace(duration,' min','')
from nf_genre g
inner join netflix_new n 
on g.show_id=n.show_id
where type='movie'
group by genre

--5  find the list of directors who have created horror and comedy movies both.
-- display director names along with number of comedy and horror movies directed by them 

select d.director,
COUNT(distinct case when genre='Horror Movies' then d.show_id end) as horror_movies,
COUNT(distinct case when genre='comedies' then d.show_id end) as comedy_movies
from nf_director d 
inner join nf_genre g
on d.show_id=g.show_id
inner join netflix_new n
on n.show_id=d.show_id
where type='movie' and genre in ('comedies','Horror Movies')
group by d.director
having COUNT(distinct genre)>1

--What is the total number of movies vs. shows available each year?
with cte as(select  YEAR(date_added) as year, 
COUNT( case when type='movie' then show_id end) as movies,
COUNT( case when type='tv show' then show_id end) as shows
from netflix_new
group by YEAR(date_added))
select YEAR,movies,shows,SUM(movies)over(order by year) as total_movies,sum(shows)over(order by year) as total_shows
from cte
order by year


--How has the volume of Netflix content (shows and movies) changed yearly?
with cte as(select year(date_added) as year,COUNT(show_id) as content_volume,
LAG(COUNT(show_id))over(order by year(date_Added)) as prev_yr_cv
from netflix_new
group by YEAR(date_added))
select YEAR, round(coalesce((content_volume-prev_yr_cv)*100.0/prev_yr_cv,0),2) as yoy_content_change
from cte

--What is the total number of titles added each year and each month?
select year(date_Added) as year,datename(month,date_Added) as month,  COUNT(show_id) as cnt
from netflix_new
group by YEAR(Date_added),datename(month,date_Added) 
order by year,cnt desc

--During which time periods (e.g., specific years or months) did Netflix add the most content?
with cte as(select year(date_Added) as year,datename(month,date_Added) as month,  COUNT(show_id) as shows_added,ROW_NUMBER()over(partition by year(date_Added) order by count(show_id) desc,datename(month,date_Added)) as rn
from netflix_new
group by YEAR(Date_added),datename(month,date_Added) )
select YEAR,MONTH,shows_added
from cte where rn=1


--Which genres are top 5 genres  for movies vs. shows?
with cte as(select type,genre,COUNT(distinct n.show_id) as genre_count,
ROW_NUMBER()over(partition by type order by COUNT(distinct n.show_id) desc) as rn
from nf_genre g
inner join netflix_new n
on g.show_id=n.show_id
group by type,genre)
select TYPE, genre
from cte 
where rn<=5

--What are the top 5 countries with the highest number of movies and shows?
with cte as(select c.country,COUNT(distinct case when type='movie' then c.show_id end) as movies,
COUNT(distinct case when type='tv show' then c.show_id end) as tv_shows,
ROW_NUMBER()over(order by COUNT(distinct case when type='movie' then c.show_id end) + COUNT(distinct case when type='tv show' then c.show_id end) desc) as rn
from nf_country c
inner join netflix_new n
on c.show_id=n.show_id
group by c.country)
select country,movies,tv_shows
from cte
where rn<=5

--What are the top 5 genres in each country?
with cte as(select cast(country as nvarchar) as country,genre,COUNT(distinct c.show_id) as cnt,
ROW_NUMBER()over(partition by country order by COUNT(distinct c.show_id) desc) as rn
from nf_country c
inner join nf_genre g
on c.show_id=g.show_id
group by country,genre)
select country,genre
from cte
where rn<6

--What are the most common ratings on Netflix, and how does the distribution vary between movies and shows
select rating ,count(case when TYPE='movie' then show_id end) as movies_rating,
count(case when TYPE='tv show' then show_id end) as tv_rating,
COUNT(show_id) as total_Rating
from netflix_new
group by rating
order by total_rating desc



