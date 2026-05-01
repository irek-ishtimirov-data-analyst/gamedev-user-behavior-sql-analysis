--ТЗ - 1: базовые метрики и когортный анализ игры.

select * from skygame.users
select * from skygame.game_sessions
select * from skygame.referral

--------------------------------------------------------------------------------------------------------------------------------
select    count(*) as cnt_row  
        , count(id_user) as cnt_users  
        , count(distinct id_user) as cnt_unique_users   
from skygame.users
 
--------------------------------------------------------------------------------------------------------------------------------
--Минимальное, максимальное время регистрации и количество клиентов с неопределённым временем регистрации.
select   max(reg_date) as max_date
       , min(reg_date) as min_date
       , sum(case when reg_date is null then 1 else 0 end) as cnt_null
from skygame.users

--------------------------------------------------------------------------------------------------------------------------------
--Количество пользователей по месяцам.
select    date_trunc('month',reg_date) as mm
        , count(id_user) as cnt
from skygame.users
group by mm
order by mm

--------------------------------------------------------------------------------------------------------------------------------
--Количество сессий без окончания и доля таких сессий, доля проблемных записей для ios среди всех ios и доля проблемных записей для android среди всех android,
--доля проблемных записей для ios среди всех проблемных записей и доля проблемных записей для android среди всех проблемных записей.
select sum (case when end_session is null then 1 else 0 end) as cnt_null_session
     , sum (case when end_session is null then 1 else 0 :: float end) / count(*) as share_null
     
     , sum (case when end_session is null and dev_type = 'ios' then 1 else 0 :: float end) / sum (case when dev_type = 'ios' then 1 else 0 end) as share_ios
     , sum (case when end_session is null and dev_type = 'android' then 1 else 0 :: float end) / sum (case when dev_type = 'android' then 1 else 0 end) as share_android
     
     , sum (case when end_session is null and dev_type = 'ios' then 1 else 0 :: float end) / sum (case when end_session is null then 1 else 0 end) as percent_ios
     , sum (case when end_session is null and dev_type = 'android' then 1 else 0 :: float end) / sum (case when end_session is null then 1 else 0 end) as percent_android
from skygame.game_sessions as gs
   join skygame.users as us
      on gs.id_user = us.id_user

--------------------------------------------------------------------------------------------------------------------------------      
--количество игровых сессий и сессий дольше 5 минут.
select count(*) as cnt_sessions_all
     , sum(case when end_session - start_session > interval '5 minute' then 1 else 0 end) as cnt_sessions_longer_five_minutes
from skygame.game_sessions

--------------------------------------------------------------------------------------------------------------------------------
--количество игровых сессий, сессий дольше 5 минут и доля сессий дольше 5 минут в разрезе по месяцам.
select date_trunc('month', start_session) as month_sessions
	 , count(*) as cnt_sessions_all
     , sum(case when end_session - start_session > interval '5 minute' then 1 else 0 end) as cnt_sessions_longer_five_minutes
     , sum(case when end_session - start_session > interval '5 minute' then 1 else 0 :: float end) / count(*) as share_sessions_longer_five_minutes
from skygame.game_sessions
group by month_sessions
order by month_sessions

--------------------------------------------------------------------------------------------------------------------------------
--Динамика средней длительности одной игровой сессии по месяцам.
select date_trunc('month', start_session) as month_sessions
	 , avg(extract(epoch from end_session - start_session) / (60 * 60)) as avg_len_session
from skygame.game_sessions
where end_session - start_session > interval '5 minute'
group by month_sessions
order by month_sessions

--------------------------------------------------------------------------------------------------------------------------------
--Динамика пользователей в день.
select    date_trunc ('day', start_session) as day_sessions
        , count (distinct id_user) as cnt_user
from skygame.game_sessions
group by day_sessions
order by day_sessions

--Динамика пользователей в неделю.
select    date_trunc ('week', start_session) as week_sessions
        , count (distinct id_user) as cnt_user
from skygame.game_sessions
group by week_sessions
order by week_sessions

--Динамика пользователей в месяц.
select    date_trunc ('month', start_session) as month_sessions
        , count (distinct id_user) as cnt_user
from skygame.game_sessions
group by month_sessions
order by month_sessions

--------------------------------------------------------------------------------------------------------------------------------
--количество пользователей которые рассылали приглашения, количество приглашений и доля приглашённых зарегистрировавшихся в игре.
select    count(distinct id_user) as cnt_users
        , count(*) as cnt_ref
        , sum(ref_reg) / count(*) as share_reg
from skygame.referral

--------------------------------------------------------------------------------------------------------------------------------
--Пользователи, которые сделали больше 5 приглашений и у которых минимум половина приглашённых зарегистрировались.
select    id_user
        , count(*) as cnt_ref
        , sum(ref_reg)/count(*) as share_reg
from skygame.referral
group by id_user
having count(*) > 5
  and sum(ref_reg) / count(*) >= 0.5
  
--------------------------------------------------------------------------------------------------------------------------------

--ТЗ - 2: Анализ динамики выручки и поведения клиентов:

select * from skygame.monetary
select * from skygame.log_prices
select * from skygame.item_list


--------------------------------------------------------------------------------------------------------------------------------
--Динамика пользовательских оплат по месяцам в разрезе по типам продукта.
select    date_trunc('month',dtime_pay) as month_pay
        , type
	    , sum(cnt_buy * price) as revenue
from skygame.monetary m
   join skygame.item_list i
      on m.id_item_buy = i.id_item
   join skygame.log_prices lp
		  on i.id_item = lp.id_item
      and m.dtime_pay >= lp.valid_from
      and m.dtime_pay < coalesce(valid_to, to_date('3000-01-01', 'YYYY-MM-DD'))
group by month_pay
       , type
order by type
    , month_pay

--------------------------------------------------------------------------------------------------------------------------------
--Среднее количество приобретаемых кристаллов на одну покупку и выручка, после повышения цены за 1 кристалл.
select    date_trunc('month',dtime_pay) as month_pay
        , avg(cnt_buy) as avg_cnt_buy
	    , sum(cnt_buy * price) as revenue
from skygame.monetary m
   join skygame.item_list i
      on m.id_item_buy = i.id_item
   join skygame.log_prices lp
		  on i.id_item = lp.id_item
      and m.dtime_pay >= lp.valid_from
      and m.dtime_pay < coalesce(valid_to, ('3000-01-01'))
where name_item = 'Crystal'      
group by month_pay
order by month_pay

--------------------------------------------------------------------------------------------------------------------------------
--K-factor и ожидаемый размер будущей когорты.
with K_f as
(select     count (r.id_user) :: float / count (distinct u.id_user) as avg_cnt_inv -- среднее количество приглашений на одного человека
         ,  sum (ref_reg) :: float / count (r.id_user) as share_reg_users     -- процент зарегистрировавшихся пользователей
         ,  sum (ref_reg) :: float / count (distinct u.id_user) as K_factor
 from skygame.users as u                       
    left join skygame.referral as r
      on u.id_user = r.id_user
),

month_coh as
( select date_trunc ('month', reg_date ) as month_cohort
      , count (id_user) as cnt_users
 from skygame.users      
 group by month_cohort
 order by month_cohort
)

select avg (cnt_users) * (select K_factor from K_f ) as V_cohort
from month_coh

--------------------------------------------------------------------------------------------------------------------------------
-- Расчет динамики активных лояльных пользователей по месяцам (LMAU):

--Критерий лояльного пользователя - пригласил >= 3 друзей, из которых >= 1 зарегистрировался.
with loyal_users as (select id_user
                    from skygame.referral as r
                    group by id_user
                    having count(*) >= 3 and sum(ref_reg) >= 1
                    )

select    date_trunc ('month', start_session) as month_sessions
        , count (distinct id_user) as cnt_lmau
from skygame.game_sessions
where id_user in (select* from loyal_users)
group by month_sessions
order by month_sessions

--------------------------------------------------------------------------------------------------------------------------------
--Критерий лояльного пользователя - заплатил суммарно больше 1000 рублей за всё время (не строго).
with crit_1000 as  (select id_user
                    from skygame.monetary as m
                        join skygame.log_prices as lp
                          on m.id_item_buy = lp.id_item
                          and dtime_pay >= valid_from
                          and dtime_pay < coalesce(valid_to, '3000-01-01')
                    group by id_user
                    having sum(cnt_buy * price) >= 1000
                    )

select    date_trunc ('month', start_session) as month_sessions
        , count (distinct gs.id_user) as cnt_users_crit_1000
from skygame.game_sessions as gs
    join crit_1000 as c
        on gs.id_user = c.id_user
group by month_sessions
order by month_sessions

--------------------------------------------------------------------------------------------------------------------------------
--Критерий лояльного пользователя - пригласил >= 3 друзей, из которых >= 1 зарегистрировался и заплатил суммарно больше 1000 рублей за всё время (не строго).
with crit_invite as (select id_user
                    from skygame.referral as r
                    group by id_user
                    having count(*) >= 3 and sum(ref_reg) >= 1
                    ),

crit_1000 as ( select id_user
                    from skygame.monetary as m
                        join skygame.log_prices as lp
                           on m.id_item_buy = lp.id_item
                           and dtime_pay between valid_from and coalesce(valid_to, '3000-01-01')
                    group by id_user
                    having sum(cnt_buy * price) >= 1000
                    )

select    date_trunc ('month', start_session) as month_sessions
        , count (distinct gs.id_user) as cnt_users_crit_invite_and_crit_1000
from skygame.game_sessions as gs
where id_user in (select * from crit_invite)
    and id_user in (select * from crit_1000)
group by month_sessions
order by month_sessions

--------------------------------------------------------------------------------------------------------------------------------
--Критерий лояльного пользователя - пригласил >= 3 друзей, из которых >= 1 зарегистрировался или заплатил суммарно больше 1000 рублей за всё время (не строго).
with crit_invite as (select id_user
                    from skygame.referral as r
                    group by id_user
                    having count(*) >= 3 and sum(ref_reg) >= 1
                    ),

crit_1000 as ( select id_user
                    from skygame.monetary as m
                        join skygame.log_prices as lp
                           on m.id_item_buy = lp.id_item
                           and dtime_pay between valid_from and coalesce(valid_to, '3000-01-01')
                    group by id_user
                    having sum(cnt_buy * price) >= 1000
                    )

select    date_trunc ('month', start_session) as month_sessions
        , count (distinct gs.id_user) as cnt_users_crit_invite_or_crit_1000
from skygame.game_sessions as gs
where id_user in (select * from crit_invite)
    or id_user in (select * from crit_1000)
group by month_sessions
order by month_sessions