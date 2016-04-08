--Washington County has provided developemnt year data (year built) for
--tax lots that is either out of data or does not exist in RLIS, this
--script add that information to RLIS tax lots

--Create column that contains only alpha-numeric characters at the
--beginning of id column, this value matches 'rno' in the 'taxlots'
--table
alter table :wash_co_year drop column if exists rno cascade;
alter table :wash_co_year add rno text;
update :wash_co_year set rno = substring(:id_col, '^\w+');

--Group by rno to have a single entry for each taxlot, the most recent
--year will be used as the development date
drop table if exists max_year cascade;
create temp table max_year as
    select
        wy.rno,
        array_agg(wy.:id_col order by wy.:id_col) as all_ids,
        max(wy.:yr_col) as yearbuilt,
        array_agg(wy.:yr_col order by wy.:yr_col) as all_years,
        max(r2t.tlno) as tlid,
        array_agg(r2t.tlno order by r2t.tlno) as all_tlid
    from :wash_co_years wy
        left join :rno2tlid r2t
            on wy.rno = r2t.account
    group by rno;

create index max_yr_rno_ix on max_year using BTREE (rno);
create index max_yr_tlid_ix on max_year using BTREE (tlid);
create index max_yr_built_ix on max_year using BTREE (yearbuilt);
vacuum analyze max_year;

--Testing verifies that either an 'rno' or 'tlid' join between the
--these two tables produces a valid match
update taxlots as t 
    set yearbuilt = mx.yearbuilt
    from max_year mx
    where (t.tlid = mx.tlid or t.rno = mx.rno)
        and t.yearbuilt < mx.yearbuilt;
