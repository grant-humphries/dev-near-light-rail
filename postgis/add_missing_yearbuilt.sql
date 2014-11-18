--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--Create new column that contains only the characters before any period (.) 
--in the id column, this value will match with rno in the rlis taxlots
alter table :yr_tbl drop column if exists rno cascade;
alter table :yr_tbl add rno text;
update :yr_tbl
	set rno = substring(:id_col, '^\w+');

--Group by rno to have a single entry for each taxlot, the most recent year will be used
--as the development date
drop table if exists missing_years_grouped cascade;
create table missing_years_grouped with oids as
	select yt.rno, array_agg(yt.:id_col order by yt.:id_col) as all_ids, 
		max(yt.:yr_col) as yearbuilt, array_agg(yt.:yr_col order by yt.:yr_col) as all_years,
		max(r2t.tlno) as tlid, array_agg(r2t.tlno order by r2t.tlno) as all_tlid
	from :yr_tbl yt
		left join :r2t_tbl r2t
		on yt.rno = r2t.account
	group by rno;

--Add indices to speed joins
drop index if exists m_years_rno_ix cascade;
create index m_years_rno_ix on missing_years_grouped using BTREE (rno);

drop index if exists m_years_tlid_ix cascade;
create index m_years_tlid_ix on missing_years_grouped using BTREE (tlid);

drop index if exists m_years_yearbuilt_ix cascade;
create index m_years_yearbuilt_ix on missing_years_grouped using BTREE (yearbuilt);

drop index if exists taxlots_rno_ix cascade;
create index taxlots_rno_ix on taxlots using BTREE (rno);

drop index if exists taxlots_tlid_ix cascade;
create index taxlots_tlid_ix on taxlots using BTREE (tlid);

/*drop index if exists taxlots_yearbuilt_ix cascade;
create index taxlots_yearbuilt_ix on taxlots using BTREE (yearbuilt);*/

--Join the yearbuilt values to rlis taxlots when there is a match by rno in the missing
--year tables and the yearbuilt value in rlis is lower than the washington county data
update taxlots as t 
	set yearbuilt = my.yearbuilt
	from missing_years_grouped my
	--I've done quite a bit of testing between the data provided by washington county
	--and what is in rlis, and if either the rno or the tlid match between the two that
	--match has proven to be sound spatially
	where (t.tlid = my.tlid or t.rno = my.rno) 
		and t.yearbuilt < my.yearbuilt;